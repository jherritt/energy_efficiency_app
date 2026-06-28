import Foundation

// MARK: - Inputs

/// Last night's main sleep session, summarized. All durations in seconds.
/// Stage fields are zero when the device did not record stages (e.g. no Apple
/// Watch); the engine treats missing stages/efficiency as neutral, never a penalty.
public struct SleepData: Sendable, Equatable {
    public var inBed: TimeInterval
    public var asleep: TimeInterval
    public var deep: TimeInterval
    public var rem: TimeInterval
    public var core: TimeInterval
    public var awake: TimeInterval
    public var bedTime: Date
    public var wakeTime: Date

    public init(inBed: TimeInterval = 0,
                asleep: TimeInterval,
                deep: TimeInterval = 0,
                rem: TimeInterval = 0,
                core: TimeInterval = 0,
                awake: TimeInterval = 0,
                bedTime: Date,
                wakeTime: Date) {
        self.inBed = inBed
        self.asleep = asleep
        self.deep = deep
        self.rem = rem
        self.core = core
        self.awake = awake
        self.bedTime = bedTime
        self.wakeTime = wakeTime
    }

    public var asleepHours: Double { asleep / 3600.0 }

    /// Time asleep over time in bed. Zero when in-bed data is unavailable.
    public var efficiency: Double { inBed > 0 ? asleep / inBed : 0 }

    /// Share of sleep that was Deep or REM. Zero when stage data is unavailable.
    public var deepRemShare: Double { asleep > 0 ? (deep + rem) / asleep : 0 }

    public var hasInBed: Bool { inBed > asleep }
    public var hasStages: Bool { (deep + rem + core) > 0 }
}

/// A single workout, used for intensity context. Workouts already contribute to
/// `activeEnergyKcal`, so they are not double-counted in drain.
public struct WorkoutSummary: Sendable, Equatable {
    public var start: Date
    public var end: Date
    public var activeEnergyKcal: Double
    public var averageHeartRate: Double?

    public init(start: Date, end: Date, activeEnergyKcal: Double, averageHeartRate: Double? = nil) {
        self.start = start
        self.end = end
        self.activeEnergyKcal = activeEnergyKcal
        self.averageHeartRate = averageHeartRate
    }

    public var minutes: Double { max(0, end.timeIntervalSince(start) / 60.0) }
}

/// Rolling baselines computed live from the user's own HealthKit history.
/// These are derived on the fly and never persisted. Every field is optional and
/// defaults to neutral so the engine degrades gracefully on a brand-new user.
public struct Baseline: Sendable, Equatable {
    public var averageSleepHours: Double?
    public var hrvBaseline: Double?
    public var restingHeartRateBaseline: Double?
    /// Standard deviation (minutes) of recent bed/wake times. Lower == more regular.
    public var sleepConsistencySDMinutes: Double?
    public var averageDailyActiveKcal: Double?
    /// The user's basal energy expenditure per day (kcal), for personalized drain.
    public var dailyBasalKcal: Double?
    /// Accumulated sleep deficit (hours), floored at 0.
    public var sleepDebtHours: Double

    public init(averageSleepHours: Double? = nil,
                hrvBaseline: Double? = nil,
                restingHeartRateBaseline: Double? = nil,
                sleepConsistencySDMinutes: Double? = nil,
                averageDailyActiveKcal: Double? = nil,
                dailyBasalKcal: Double? = nil,
                sleepDebtHours: Double = 0) {
        self.averageSleepHours = averageSleepHours
        self.hrvBaseline = hrvBaseline
        self.restingHeartRateBaseline = restingHeartRateBaseline
        self.sleepConsistencySDMinutes = sleepConsistencySDMinutes
        self.averageDailyActiveKcal = averageDailyActiveKcal
        self.dailyBasalKcal = dailyBasalKcal
        self.sleepDebtHours = sleepDebtHours
    }

    /// Neutral baseline: every enhancement multiplier resolves to 1.0 / no penalty.
    public static let neutral = Baseline()
}

/// User targets. Bedtime/wake come from the HealthKit Sleep Schedule where
/// available, else these in-app defaults.
public struct UserTargets: Sendable, Equatable {
    public var sleepTargetHours: Double
    /// Target bedtime as clock components (hour/minute).
    public var bedTarget: DateComponents
    public var wakeTarget: DateComponents
    public var onTimeWindowMinutes: Double
    public var moveGoalKcal: Double
    public var exerciseGoalMinutes: Double
    public var standGoalHours: Double
    public var waterGoalML: Double

    public init(sleepTargetHours: Double = ScoringConstants.sleepTargetHours,
                bedTarget: DateComponents = DateComponents(hour: 23, minute: 0),
                wakeTarget: DateComponents = DateComponents(hour: 7, minute: 0),
                onTimeWindowMinutes: Double = ScoringConstants.onTimeToleranceMin,
                moveGoalKcal: Double = ScoringConstants.defaultMoveGoalKcal,
                exerciseGoalMinutes: Double = ScoringConstants.defaultExerciseGoalMin,
                standGoalHours: Double = ScoringConstants.defaultStandGoalHours,
                waterGoalML: Double = ScoringConstants.defaultWaterGoalML) {
        self.sleepTargetHours = sleepTargetHours
        self.bedTarget = bedTarget
        self.wakeTarget = wakeTarget
        self.onTimeWindowMinutes = onTimeWindowMinutes
        self.moveGoalKcal = moveGoalKcal
        self.exerciseGoalMinutes = exerciseGoalMinutes
        self.standGoalHours = standGoalHours
        self.waterGoalML = waterGoalML
    }

    public static let `default` = UserTargets()
}

/// Everything the engine needs for "today", read live from HealthKit.
/// `nil` health fields mean "no data" and are handled as neutral, not zero-penalty.
public struct HealthSnapshot: Sendable {
    /// False when the user has not granted HealthKit read access.
    public var isAuthorized: Bool
    public var sleep: SleepData?
    public var activeEnergyKcal: Double
    public var basalEnergyKcal: Double
    public var steps: Int
    public var exerciseMinutes: Double
    public var standHours: Double
    /// Apple ring goals, if available (else engine falls back to UserTargets).
    public var moveGoalKcal: Double?
    public var exerciseGoalMinutes: Double?
    public var standGoalHours: Double?
    public var hrvSDNN: Double?
    public var restingHeartRate: Double?
    public var waterML: Double
    public var timeInDaylightMinutes: Double?
    public var elevatedHeartRateMinutes: Double?
    public var lastCaffeine: Date?
    public var workouts: [WorkoutSummary]
    public var baseline: Baseline
    /// "Now" for the snapshot (lets widgets project future timeline entries).
    public var asOf: Date

    public init(isAuthorized: Bool = true,
                sleep: SleepData? = nil,
                activeEnergyKcal: Double = 0,
                basalEnergyKcal: Double = 0,
                steps: Int = 0,
                exerciseMinutes: Double = 0,
                standHours: Double = 0,
                moveGoalKcal: Double? = nil,
                exerciseGoalMinutes: Double? = nil,
                standGoalHours: Double? = nil,
                hrvSDNN: Double? = nil,
                restingHeartRate: Double? = nil,
                waterML: Double = 0,
                timeInDaylightMinutes: Double? = nil,
                elevatedHeartRateMinutes: Double? = nil,
                lastCaffeine: Date? = nil,
                workouts: [WorkoutSummary] = [],
                baseline: Baseline = .neutral,
                asOf: Date) {
        self.isAuthorized = isAuthorized
        self.sleep = sleep
        self.activeEnergyKcal = activeEnergyKcal
        self.basalEnergyKcal = basalEnergyKcal
        self.steps = steps
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.moveGoalKcal = moveGoalKcal
        self.exerciseGoalMinutes = exerciseGoalMinutes
        self.standGoalHours = standGoalHours
        self.hrvSDNN = hrvSDNN
        self.restingHeartRate = restingHeartRate
        self.waterML = waterML
        self.timeInDaylightMinutes = timeInDaylightMinutes
        self.elevatedHeartRateMinutes = elevatedHeartRateMinutes
        self.lastCaffeine = lastCaffeine
        self.workouts = workouts
        self.baseline = baseline
        self.asOf = asOf
    }

    public var hasSleepData: Bool { sleep != nil }
}

// MARK: - Outputs

/// The six-line points ledger for the day.
public struct PointsBreakdown: Sendable, Equatable {
    public var move: Double
    public var exercise: Double
    public var stand: Double
    public var bedtime: Double
    public var wake: Double
    public var hydration: Double
    /// True when sleep was detected, so bedtime/wake lines are meaningful.
    public var sleepPointsAvailable: Bool

    public init(move: Double = 0, exercise: Double = 0, stand: Double = 0,
                bedtime: Double = 0, wake: Double = 0, hydration: Double = 0,
                sleepPointsAvailable: Bool = true) {
        self.move = move
        self.exercise = exercise
        self.stand = stand
        self.bedtime = bedtime
        self.wake = wake
        self.hydration = hydration
        self.sleepPointsAvailable = sleepPointsAvailable
    }

    public var total: Double { move + exercise + stand + bedtime + wake + hydration }

    /// The maximum points earnable today (100 normally, 80 with no sleep data).
    public var maxAvailable: Double {
        sleepPointsAvailable ? ScoringConstants.totalPointsWithSleep : ScoringConstants.totalPointsNoSleep
    }
}

/// The complete computed score for a day. `nil` battery/efficiency means the
/// user has not authorized HealthKit (render as "--", never a fabricated 0).
public struct DayScore: Sendable, Equatable {
    public var date: Date
    public var isAuthorized: Bool
    public var hasSleepData: Bool

    /// Battery level at wake (0...100), the single charge event of the day.
    public var morningBattery: Double?
    /// Battery level right now (0...100) after drain.
    public var currentBattery: Double?
    /// Battery-% of energy spent so far today.
    public var energySpent: Double
    /// Hero number: 0...100 efficiency.
    public var efficiency: Double?

    public var points: PointsBreakdown
    /// Difficulty-weighted XP for the gamification/level system (never affects efficiency).
    public var xp: Double
    /// True when caffeine was logged too close to bedtime.
    public var caffeineLateFlag: Bool

    public init(date: Date,
                isAuthorized: Bool,
                hasSleepData: Bool,
                morningBattery: Double?,
                currentBattery: Double?,
                energySpent: Double,
                efficiency: Double?,
                points: PointsBreakdown,
                xp: Double,
                caffeineLateFlag: Bool) {
        self.date = date
        self.isAuthorized = isAuthorized
        self.hasSleepData = hasSleepData
        self.morningBattery = morningBattery
        self.currentBattery = currentBattery
        self.energySpent = energySpent
        self.efficiency = efficiency
        self.points = points
        self.xp = xp
        self.caffeineLateFlag = caffeineLateFlag
    }

    /// A neutral "connect Health" placeholder used before authorization.
    public static func unauthorized(date: Date) -> DayScore {
        DayScore(date: date, isAuthorized: false, hasSleepData: false,
                 morningBattery: nil, currentBattery: nil, energySpent: 0,
                 efficiency: nil, points: PointsBreakdown(sleepPointsAvailable: false),
                 xp: 0, caffeineLateFlag: false)
    }
}

/// Progression state derived live from a window of past `DayScore`s.
public struct Progression: Sendable, Equatable {
    public var level: Int
    public var totalXP: Double
    public var xpIntoLevel: Double
    public var xpForNextLevel: Double
    public var pointsStreak: Int
    public var sleepStreak: Int

    public init(level: Int, totalXP: Double, xpIntoLevel: Double, xpForNextLevel: Double,
                pointsStreak: Int, sleepStreak: Int) {
        self.level = level
        self.totalXP = totalXP
        self.xpIntoLevel = xpIntoLevel
        self.xpForNextLevel = xpForNextLevel
        self.pointsStreak = pointsStreak
        self.sleepStreak = sleepStreak
    }
}
