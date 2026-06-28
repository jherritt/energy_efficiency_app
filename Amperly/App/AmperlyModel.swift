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
        self.hasRequestedHealthAccess = Self.healthAccessRequested()
    }

    // MARK: Health access

    /// Whether HealthKit auth has been requested before (false -> show onboarding).
    static func healthAccessRequested() -> Bool {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            return HealthKitService.shared.hasRequestedAuthorization()
        }
        return false
        #else
        return false
        #endif
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
        hasRequestedHealthAccess = Self.healthAccessRequested()
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
            self.progression = ScoringEngine.progression(history: [dayScore])
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
}
