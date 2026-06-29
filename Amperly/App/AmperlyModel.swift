import Foundation
import Observation
import EnergyKit

// MARK: - SettingsStore (UserDefaults-backed, the in-app fallback prefs)

/// Small persistence layer for the handful of user-tunable preferences Amperly
/// keeps locally: the fallback bed/wake times, the daily water goal, and the
/// opt-in flag for the low-efficiency nudge. Nothing here ever leaves the device.
struct SettingsStore {

    enum Keys {
        static let bedHour = "bedTargetHour"
        static let bedMinute = "bedTargetMinute"
        static let wakeHour = "wakeTargetHour"
        static let wakeMinute = "wakeTargetMinute"
        static let waterGoalML = "waterGoalML"
        static let lowEfficiencyNudge = "lowEfficiencyNudgeEnabled"
        static let hasStoredTargets = "hasStoredTargets"
    }

    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    // MARK: Low-efficiency nudge opt-in

    var lowEfficiencyNudgeEnabled: Bool {
        get { defaults.bool(forKey: Keys.lowEfficiencyNudge) }
        nonmutating set { defaults.set(newValue, forKey: Keys.lowEfficiencyNudge) }
    }

    // MARK: Targets <-> UserDefaults

    /// Load targets, falling back to `UserTargets.default` for anything not stored yet.
    func loadTargets() -> UserTargets {
        let base = UserTargets.default
        guard defaults.bool(forKey: Keys.hasStoredTargets) else { return base }

        let bedHour = defaults.object(forKey: Keys.bedHour) as? Int ?? base.bedTarget.hour ?? 23
        let bedMinute = defaults.object(forKey: Keys.bedMinute) as? Int ?? base.bedTarget.minute ?? 0
        let wakeHour = defaults.object(forKey: Keys.wakeHour) as? Int ?? base.wakeTarget.hour ?? 7
        let wakeMinute = defaults.object(forKey: Keys.wakeMinute) as? Int ?? base.wakeTarget.minute ?? 0
        let storedWater = defaults.object(forKey: Keys.waterGoalML) as? Double
        let water = (storedWater.map { $0 > 0 } ?? false) ? storedWater! : base.waterGoalML

        return UserTargets(
            sleepTargetHours: base.sleepTargetHours,
            bedTarget: DateComponents(hour: bedHour, minute: bedMinute),
            wakeTarget: DateComponents(hour: wakeHour, minute: wakeMinute),
            onTimeWindowMinutes: base.onTimeWindowMinutes,
            moveGoalKcal: base.moveGoalKcal,
            exerciseGoalMinutes: base.exerciseGoalMinutes,
            standGoalHours: base.standGoalHours,
            waterGoalML: water
        )
    }

    /// Persist the user-editable subset (bed/wake + water goal).
    func saveTargets(_ targets: UserTargets) {
        defaults.set(targets.bedTarget.hour ?? 23, forKey: Keys.bedHour)
        defaults.set(targets.bedTarget.minute ?? 0, forKey: Keys.bedMinute)
        defaults.set(targets.wakeTarget.hour ?? 7, forKey: Keys.wakeHour)
        defaults.set(targets.wakeTarget.minute ?? 0, forKey: Keys.wakeMinute)
        defaults.set(targets.waterGoalML, forKey: Keys.waterGoalML)
        defaults.set(true, forKey: Keys.hasStoredTargets)
    }
}

// MARK: - AmperlyModel (single source of truth)

/// The app's view model. Owns the live score, progression, user targets, and
/// loading state, and bridges the UI to the on-device `EnergyKit` engine.
/// Injected via `.environment` so every screen reads the same instance.
@MainActor
@Observable
final class AmperlyModel {

    /// The computed score for "now". `nil` before the first refresh.
    /// Note that `score.efficiency` / battery may themselves be nil when
    /// HealthKit is not authorized -> the UI renders "--".
    var score: DayScore?

    /// Level / XP / streak state derived from recent history. `nil` until refreshed.
    var progression: Progression?

    /// Active user targets (bed/wake/water goal etc.).
    var targets: UserTargets

    /// True while a refresh is in flight (drives pull-to-refresh / spinners).
    var isRefreshing: Bool = false

    /// True once HealthKit read access has been requested at least once.
    /// Used by routing to decide onboarding vs. main UI.
    var hasRequestedHealthAccess: Bool

    /// Opt-in for the gentle low-efficiency nudge.
    var lowEfficiencyNudgeEnabled: Bool {
        didSet { settings.lowEfficiencyNudgeEnabled = lowEfficiencyNudgeEnabled }
    }

    private let settings: SettingsStore

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.targets = settings.loadTargets()
        self.lowEfficiencyNudgeEnabled = settings.lowEfficiencyNudgeEnabled
        // Resolved asynchronously on launch via refreshHealthAccessState();
        // the HealthKit actor cannot be queried from a synchronous init.
        self.hasRequestedHealthAccess = false
    }

    // MARK: Health access

    /// Whether HealthKit auth has been requested before (false -> show onboarding).
    static func healthAccessRequested() async -> Bool {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            return await HealthKitService.shared.hasRequestedAuthorization()
        }
        return false
        #else
        return false
        #endif
    }

    /// Refresh the "has requested Health access" flag. Call once on launch so
    /// routing (onboarding vs. main UI) settles correctly.
    func refreshHealthAccessState() async {
        hasRequestedHealthAccess = await Self.healthAccessRequested()
    }

    /// Prompt for HealthKit read access, then refresh. Safe to call repeatedly;
    /// failures are swallowed (Apple never confirms read grants) and the UI
    /// degrades to "--" via the engine's unauthorized snapshot.
    func requestHealthAccess() async {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            try? await HealthKitService.shared.requestAuthorization()
        }
        #endif
        // We have now prompted the user. Advance to the dashboard regardless of the
        // outcome (granted, denied, or HealthKit unavailable); the dashboard renders
        // "--" when there is no access, and the next launch re-derives the real state.
        hasRequestedHealthAccess = true
        await refresh()
    }

    // MARK: Refresh

    /// Pull a fresh snapshot, score it, and recompute progression. Never throws:
    /// on any failure or on unsupported platforms it falls back to an
    /// unauthorized score so the UI shows "--" rather than crashing.
    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let now = Date()
        let currentTargets = targets

        #if os(iOS)
        if #available(iOS 17.0, *) {
            let snapshot = await HealthKitService.shared.currentSnapshot(targets: currentTargets, now: now)
            let dayScore = ScoringEngine.score(snapshot, targets: currentTargets)
            self.score = dayScore
            // Derive streaks/levels from the user's own recent history (read live,
            // nothing stored). Fall back to today only if history is unavailable.
            let history = await HealthKitService.shared.recentDayScores(days: 14, targets: currentTargets, now: now)
            self.progression = ScoringEngine.progression(history: history.isEmpty ? [dayScore] : history)
            await scheduleNudgeIfNeeded()
            return
        }
        #endif

        // Non-iOS / pre-17 fallback: present the neutral unauthorized state.
        let unauthorized = DayScore.unauthorized(date: now)
        self.score = unauthorized
        self.progression = ScoringEngine.progression(history: [unauthorized])
    }

    // MARK: Targets editing

    /// Update targets in memory and persist the editable subset.
    func updateTargets(_ newTargets: UserTargets) {
        targets = newTargets
        settings.saveTargets(newTargets)
    }

    /// Toggle the low-efficiency nudge; requests notification permission when
    /// enabling, then (re)schedules or cancels the local nudge accordingly.
    func setLowEfficiencyNudgeEnabled(_ enabled: Bool) async {
        lowEfficiencyNudgeEnabled = enabled   // didSet persists it
        #if os(iOS)
        if enabled {
            _ = await NotificationManager.shared.requestAuthorization()
        }
        #endif
        await scheduleNudgeIfNeeded()
    }

    /// Schedule or cancel the opt-in afternoon nudge based on the latest score.
    private func scheduleNudgeIfNeeded() async {
        #if os(iOS)
        guard let score else { return }
        await NotificationManager.shared.refreshLowEfficiencyNudge(
            isEnabled: lowEfficiencyNudgeEnabled,
            efficiency: score.efficiency,
            energySpent: score.energySpent,
            pointsEarned: score.points.total)
        #endif
    }
}

#if DEBUG
extension AmperlyModel {
    /// Sample model for SwiftUI previews (DEBUG only).
    static var preview: AmperlyModel {
        let model = AmperlyModel()
        model.score = DayScore(
            date: Date(), isAuthorized: true, hasSleepData: true,
            morningBattery: 92, currentBattery: 64, energySpent: 28,
            efficiency: 88,
            points: PointsBreakdown(move: 22, exercise: 16, stand: 12,
                                    bedtime: 9, wake: 8, hydration: 14,
                                    sleepPointsAvailable: true),
            xp: 320, caffeineLateFlag: false)
        model.progression = Progression(level: 6, totalXP: 4200, xpIntoLevel: 320,
                                        xpForNextLevel: 800, pointsStreak: 12, sleepStreak: 5)
        return model
    }
}
#endif
