import Foundation

/// Amperly's scoring engine: pure, deterministic functions that turn a
/// `HealthSnapshot` into a `DayScore`. No HealthKit, no I/O, no global state, so
/// it is fully unit-testable and identical in the app and the widget.
///
/// Design rule: every enhancement (sleep stages, HRV/RHR recovery, sleep debt,
/// personalized basal drain, intensity, daylight, difficulty weighting) resolves
/// to NEUTRAL when its data is absent, so a user with only a phone still gets the
/// clean base model, and the documented worked example is reproducible.
public enum ScoringEngine {

    // MARK: - Public entry point

    /// Compute the full day score from a snapshot and the user's targets.
    public static func score(_ snapshot: HealthSnapshot,
                             targets: UserTargets = .default) -> DayScore {
        guard snapshot.isAuthorized else {
            return .unauthorized(date: snapshot.asOf)
        }

        let hasSleep = snapshot.hasSleepData
        let morning = morningBattery(snapshot: snapshot, targets: targets)
        let spent = energySpent(snapshot: snapshot, targets: targets)
        let current = morning.map { currentBattery(morning: $0, energySpent: spent) }
        let pts = points(snapshot: snapshot, targets: targets)
        let eff = efficiency(points: pts, energySpent: spent)
        let xpValue = xp(points: pts, snapshot: snapshot, targets: targets)
        let caffeine = caffeineLate(snapshot: snapshot, targets: targets)

        return DayScore(date: snapshot.asOf,
                        isAuthorized: true,
                        hasSleepData: hasSleep,
                        morningBattery: morning,
                        currentBattery: current,
                        energySpent: spent,
                        efficiency: eff,
                        points: pts,
                        xp: xpValue,
                        caffeineLateFlag: caffeine)
    }

    // MARK: - Morning charge (sleep -> battery)

    /// Battery level at wake (0...100). Returns nil only when unauthorized.
    /// With no sleep detected, boots to a neutral 50%.
    public static func morningBattery(snapshot: HealthSnapshot,
                                      targets: UserTargets) -> Double? {
        guard snapshot.isAuthorized else { return nil }
        guard let sleep = snapshot.sleep else { return 50.0 }

        // 1) Duration component (0...85), with a boot floor for any real sleep.
        let target = max(1.0, targets.sleepTargetHours)
        var durationCharge = ScoringConstants.durationChargeMax * min(sleep.asleepHours / target, 1.0)
        if sleep.asleepHours >= 1.0 {
            durationCharge = max(durationCharge, ScoringConstants.durationFloorIfAsleep)
        }

        // Enhancement multipliers (neutral == 1.0 when data is absent).
        let quality = qualityMultiplier(sleep)
        let recovery = recoveryMultiplier(snapshot: snapshot)

        // 2) Schedule consistency bonus (0...15).
        let bedDev = deviationMinutes(date: sleep.bedTime, target: targets.bedTarget)
        let wakeDev = deviationMinutes(date: sleep.wakeTime, target: targets.wakeTarget)
        let consistency = ScoringConstants.consistencyBonusMax
            * (0.5 * onTimeFade(bedDev) + 0.5 * onTimeFade(wakeDev))

        // 3) 7-day regularity bonus (0...5) and multi-day sleep-debt penalty.
        let regularity = regularityBonus(snapshot.baseline)
        let debtPenalty = min(ScoringConstants.debtPenaltyMax,
                              ScoringConstants.debtPenaltyPerHour * max(0, snapshot.baseline.sleepDebtHours))

        let charge = durationCharge * quality * recovery + consistency + regularity - debtPenalty
        return clamp(charge, 0, 100)
    }

    /// Sleep-quality multiplier from efficiency + Deep/REM share. Neutral 1.0
    /// when the device recorded no stages or no in-bed time.
    static func qualityMultiplier(_ sleep: SleepData) -> Double {
        let effRatio = sleep.hasInBed ? sleep.efficiency / ScoringConstants.targetSleepEfficiency : 1.0
        let stageRatio = sleep.hasStages ? sleep.deepRemShare / ScoringConstants.targetDeepRemShare : 1.0
        let raw = 0.5 * effRatio + 0.5 * stageRatio
        return clamp(raw, ScoringConstants.qualityMin, ScoringConstants.qualityMax)
    }

    /// Overnight-recovery multiplier from HRV (higher is better) and resting HR
    /// (lower is better) versus the user's own baseline. Neutral 1.0 when absent.
    static func recoveryMultiplier(snapshot: HealthSnapshot) -> Double {
        let b = snapshot.baseline
        let hrvRatio: Double = {
            guard let hrv = snapshot.hrvSDNN, let base = b.hrvBaseline, base > 0 else { return 1.0 }
            return hrv / base
        }()
        let rhrRatio: Double = {
            guard let rhr = snapshot.restingHeartRate, let base = b.restingHeartRateBaseline, rhr > 0 else { return 1.0 }
            return base / rhr
        }()
        let raw = 0.5 * hrvRatio + 0.5 * rhrRatio
        return clamp(raw, ScoringConstants.recoveryMin, ScoringConstants.recoveryMax)
    }

    /// 7-day regularity bonus (0...5) from the standard deviation of recent
    /// bed/wake times. Neutral 0 when no baseline variance is known.
    static func regularityBonus(_ baseline: Baseline) -> Double {
        guard let sd = baseline.sleepConsistencySDMinutes else { return 0 }
        // <= 20 min SD -> full bonus; >= 80 min SD -> none.
        let factor = clamp((80.0 - sd) / 60.0, 0, 1)
        return ScoringConstants.regularityBonusMax * factor
    }

    // MARK: - Drain (battery depletion)

    /// Battery-% of energy spent since wake (baseline + activity, minus daylight relief).
    public static func energySpent(snapshot: HealthSnapshot, targets: UserTargets) -> Double {
        let wake = snapshot.sleep?.wakeTime ?? startOfDay(snapshot.asOf, fallbackWake: targets.wakeTarget)
        let hoursAwake = max(0, snapshot.asOf.timeIntervalSince(wake) / 3600.0)

        // Personalized baseline drain rate from the user's basal metabolism.
        var baselineRate = ScoringConstants.baselineDrainPerHour
        if let basal = snapshot.baseline.dailyBasalKcal, basal > 0 {
            baselineRate = clamp(ScoringConstants.baselineDrainPerHour * basal / ScoringConstants.referenceBasalKcal,
                                 ScoringConstants.baselineRateMin, ScoringConstants.baselineRateMax)
        }
        let baselineDrain = baselineRate * hoursAwake

        // Activity drain scaled by a bounded intensity factor from elevated-HR time.
        let intensity = 1.0 + (ScoringConstants.intensityMax - 1.0)
            * clamp((snapshot.elevatedHeartRateMinutes ?? 0) / 60.0, 0, 1)
        let activityDrain = ScoringConstants.activityDrainPerKcal * snapshot.activeEnergyKcal * intensity

        // Daylight relief: time outdoors slows perceived drain (alertness).
        let relief = ScoringConstants.daylightReliefMax
            * clamp((snapshot.timeInDaylightMinutes ?? 0) / ScoringConstants.daylightFullReliefMinutes, 0, 1)

        return (baselineDrain + activityDrain) * (1 - relief)
    }

    /// Current battery after drain (0...100).
    public static func currentBattery(morning: Double, energySpent: Double) -> Double {
        clamp(morning - energySpent, 0, 100)
    }

    // MARK: - Points ledger

    public static func points(snapshot: HealthSnapshot, targets: UserTargets) -> PointsBreakdown {
        let moveGoal = snapshot.moveGoalKcal ?? targets.moveGoalKcal
        let exGoal = snapshot.exerciseGoalMinutes ?? targets.exerciseGoalMinutes
        let standGoal = snapshot.standGoalHours ?? targets.standGoalHours

        let move = ScoringConstants.movePointsMax * fraction(snapshot.activeEnergyKcal, moveGoal)
        let exercise = ScoringConstants.exercisePointsMax * fraction(snapshot.exerciseMinutes, exGoal)
        let stand = ScoringConstants.standPointsMax * fraction(snapshot.standHours, standGoal)
        let hydration = ScoringConstants.hydrationPointsMax * fraction(snapshot.waterML, targets.waterGoalML)

        var bedtime = 0.0, wake = 0.0
        let hasSleep = snapshot.hasSleepData
        if let sleep = snapshot.sleep {
            let bedDev = deviationMinutes(date: sleep.bedTime, target: targets.bedTarget)
            let wakeDev = deviationMinutes(date: sleep.wakeTime, target: targets.wakeTarget)
            bedtime = ScoringConstants.bedtimePointsMax * onTimeFade(bedDev)
            wake = ScoringConstants.wakePointsMax * onTimeFade(wakeDev)
        }

        return PointsBreakdown(move: move, exercise: exercise, stand: stand,
                               bedtime: bedtime, wake: wake, hydration: hydration,
                               sleepPointsAvailable: hasSleep)
    }

    // MARK: - Efficiency (hero number)

    /// Efficiency 0...100, keyed to energy spent so it is stable at any hour.
    public static func efficiency(points: PointsBreakdown, energySpent: Double) -> Double {
        let total = points.maxAvailable
        let floor = ScoringConstants.efficiencyFloor * total / ScoringConstants.totalPointsWithSleep
        let expected = max(total * min(energySpent / ScoringConstants.dailyEnergyBudget, 1.0), floor)
        return clamp(100.0 * points.total / expected, 0, 100)
    }

    // MARK: - XP / difficulty weighting (gamification only)

    /// Difficulty-weighted points feeding the level system. Goals the user
    /// usually misses are worth more. Never influences the efficiency score.
    public static func xp(points: PointsBreakdown, snapshot: HealthSnapshot, targets: UserTargets) -> Double {
        let moveGoal = snapshot.moveGoalKcal ?? targets.moveGoalKcal
        let moveWeight = difficultyWeight(baseline: snapshot.baseline.averageDailyActiveKcal, goal: moveGoal)
        // Move and Exercise are difficulty-weighted; the rest count at face value.
        return points.move * moveWeight
            + points.exercise * difficultyWeightDefault
            + points.stand
            + points.bedtime
            + points.wake
            + points.hydration
    }

    private static let difficultyWeightDefault = 1.0

    static func difficultyWeight(baseline: Double?, goal: Double) -> Double {
        guard goal > 0, let b = baseline else { return ScoringConstants.difficultyWeightMin }
        let ratio = clamp(b / goal, 0, 1) // <1 means usually below goal -> harder
        return clamp(ScoringConstants.difficultyWeightMax
                     - (ScoringConstants.difficultyWeightMax - ScoringConstants.difficultyWeightMin) * ratio,
                     ScoringConstants.difficultyWeightMin, ScoringConstants.difficultyWeightMax)
    }

    // MARK: - Caffeine flag

    static func caffeineLate(snapshot: HealthSnapshot, targets: UserTargets) -> Bool {
        guard let last = snapshot.lastCaffeine else { return false }
        guard let bedToday = nextOccurrence(of: targets.bedTarget, after: last) else { return false }
        let hoursBeforeBed = bedToday.timeIntervalSince(last) / 3600.0
        return hoursBeforeBed <= ScoringConstants.caffeineCutoffHoursBeforeBed
    }

    // MARK: - Progression (streaks + levels) over a window of past days

    /// Derive level/streaks from a chronological window of past day scores
    /// (oldest...newest), computed live by the app. Nothing is persisted.
    public static func progression(history: [DayScore]) -> Progression {
        let totalXP = history.reduce(0) { $0 + $1.xp }
        let lvl = level(forXP: totalXP)
        let floorXP = xpThreshold(forLevel: lvl)
        let nextXP = xpThreshold(forLevel: lvl + 1)

        // Streaks count consecutive most-recent days meeting a bar.
        let ordered = history // assumed oldest -> newest
        let pointsStreak = trailingStreak(ordered) { $0.points.total >= 0.7 * $0.points.maxAvailable }
        let sleepStreak = trailingStreak(ordered) { $0.hasSleepData && ($0.morningBattery ?? 0) >= 70 }

        return Progression(level: lvl, totalXP: totalXP,
                           xpIntoLevel: totalXP - floorXP,
                           xpForNextLevel: nextXP - floorXP,
                           pointsStreak: pointsStreak, sleepStreak: sleepStreak)
    }

    /// Cumulative XP needed to *reach* a level: base * L*(L-1)/2 (level 1 == 0 XP).
    public static func xpThreshold(forLevel level: Int) -> Double {
        let l = max(1, level)
        return ScoringConstants.xpPerLevelBase * Double(l * (l - 1)) / 2.0
    }

    public static func level(forXP xp: Double) -> Int {
        var l = 1
        while xpThreshold(forLevel: l + 1) <= xp { l += 1 }
        return l
    }

    static func trailingStreak(_ ordered: [DayScore], meets: (DayScore) -> Bool) -> Int {
        var count = 0
        for day in ordered.reversed() {
            if meets(day) { count += 1 } else { break }
        }
        return count
    }

    // MARK: - Shared helpers

    /// On-time fade c(d): 1.0 if d <= 30, 0.0 if d >= 90, else linear.
    public static func onTimeFade(_ deviationMinutes: Double) -> Double {
        let lo = ScoringConstants.onTimeToleranceMin
        let hi = ScoringConstants.onTimeZeroMin
        if deviationMinutes <= lo { return 1.0 }
        if deviationMinutes >= hi { return 0.0 }
        return (hi - deviationMinutes) / (hi - lo)
    }

    /// Minutes between a timestamp's clock time and a target clock time, wrapping
    /// around midnight (so 23:50 vs 00:10 == 20 minutes).
    public static func deviationMinutes(date: Date, target: DateComponents) -> Double {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let comps = cal.dateComponents([.hour, .minute], from: date)
        let actual = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let want = (target.hour ?? 0) * 60 + (target.minute ?? 0)
        let diff = abs(actual - want)
        return Double(min(diff, 1440 - diff))
    }

    static func fraction(_ value: Double, _ goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(value / goal, 1.0)
    }

    static func clamp(_ x: Double, _ lo: Double, _ hi: Double) -> Double {
        min(max(x, lo), hi)
    }

    /// Wake-time fallback when no sleep was detected: today's target wake time.
    static func startOfDay(_ now: Date, fallbackWake: DateComponents) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let today = cal.startOfDay(for: now)
        return cal.date(byAdding: DateComponents(hour: fallbackWake.hour ?? 7,
                                                 minute: fallbackWake.minute ?? 0),
                        to: today) ?? today
    }

    /// The next time the given clock components occur at or after a reference date.
    static func nextOccurrence(of comps: DateComponents, after date: Date) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal.nextDate(after: date,
                            matching: DateComponents(hour: comps.hour, minute: comps.minute),
                            matchingPolicy: .nextTime)
    }
}
