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

    /// Today's intraday battery/efficiency curve for the charts. Empty until the
    /// first refresh (or when unauthorized).
    var hourlySeries: [EnergySeriesPoint] = []

    /// The last 30 days scored live from Apple Health (oldest -> newest,
    /// including today). Powers the Progress tab's history charts and list.
    var history: [DayScore] = []

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

            // Intraday curve for the efficiency/battery charts, rebuilt live from
            // hourly Apple Health checkpoints run through the same engine.
            let hourly = await HealthKitService.shared.todayHourlyActivity(now: now)
            self.hourlySeries = ScoringEngine.daySeries(snapshot: snapshot, hourly: hourly, targets: currentTargets)

            // Lifetime progression, persisted on-device (nothing transmitted). On the
            // very first run we seed from the last 90 days of Apple Health so streaks
            // and level reflect existing history; after that we accumulate forever,
            // one record per day, so the user's level keeps climbing for months/years.
            let store = ProgressionStore.shared
            // One-time migration: v1 records were bucketed onto the wrong calendar
            // day (backfill off-by-one), which broke XP totals and streaks. Wipe and
            // rebuild from Apple Health with the fixed derivation.
            let schemaKey = "progressionSchemaVersion"
            if UserDefaults.standard.integer(forKey: schemaKey) < 2 {
                store.reset()
                UserDefaults.standard.set(2, forKey: schemaKey)
            }
            if store.isEmpty {
                let backfill = await HealthKitService.shared.recentDayScores(days: 90, targets: currentTargets, now: now)
                store.recordAll(backfill.map(ScoringEngine.dailyProgress(from:)))
            }
            if dayScore.isAuthorized {
                store.record(ScoringEngine.dailyProgress(from: dayScore))
            }
            self.progression = ScoringEngine.progression(from: store.allDays())

            // Last 30 days for the Progress tab, computed live (nothing stored).
            self.history = await HealthKitService.shared.recentDayScores(days: 30, targets: currentTargets, now: now)

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

extension AmperlyModel {
    /// Sample model for SwiftUI previews and placeholders.
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
                                        xpForNextLevel: 800, pointsStreak: 12, sleepStreak: 5,
                                        longestPointsStreak: 28, longestSleepStreak: 14)
        model.score?.sleepDebtHours = 3.2
        // A plausible intraday curve so the charts render in previews.
        let cal = Calendar.current
        let wake = cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        let effCurve: [Double] = [100, 100, 96, 88, 84, 90, 93, 89, 88]
        let batCurve: [Double] = [92, 88, 84, 79, 74, 70, 68, 66, 64]
        model.hourlySeries = (0..<9).map { i in
            EnergySeriesPoint(date: wake.addingTimeInterval(Double(i) * 3600),
                              battery: batCurve[i], efficiency: effCurve[i],
                              energySpent: Double(i) * 4.2, points: Double(i) * 9)
        }
        // A plausible month of history for the Progress tab.
        let effHistory: [Double] = [72, 81, 88, 64, 90, 95, 78, 84, 91, 70,
                                    86, 93, 75, 88, 96, 82, 68, 89, 94, 79,
                                    85, 92, 71, 87, 90, 83, 76, 94, 91, 88]
        model.history = (0..<30).map { i in
            let day = cal.date(byAdding: .day, value: i - 29, to: cal.startOfDay(for: Date())) ?? Date()
            let eff = effHistory[i]
            let pts = eff * 0.9 + Double(i % 7)
            return DayScore(date: day, isAuthorized: true, hasSleepData: i % 9 != 4,
                            morningBattery: 70 + Double(i % 5) * 6,
                            currentBattery: 18 + Double(i % 4) * 5,
                            energySpent: 62 + Double(i % 6) * 3,
                            efficiency: eff,
                            points: PointsBreakdown(move: pts * 0.25, exercise: pts * 0.20,
                                                    stand: pts * 0.15, bedtime: pts * 0.10,
                                                    wake: pts * 0.10, hydration: pts * 0.20,
                                                    sleepPointsAvailable: i % 9 != 4),
                            xp: pts, caffeineLateFlag: false,
                            sleepDebtHours: Double(i % 4),
                            batteryIsEstimated: i % 9 == 4)
        }
        return model
    }
}
