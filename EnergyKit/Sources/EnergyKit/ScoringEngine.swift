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
        // The charge is an estimate when nothing was recorded but history let us
        // do better than the flat neutral default (either fallback tier).
        let estimated = !hasSleep
            && (snapshot.baseline.typicalMorningCharge != nil
                || snapshot.baseline.averageSleepHours != nil)

        return DayScore(date: snapshot.asOf,
                        isAuthorized: true,
                        hasSleepData: hasSleep,
                        morningBattery: morning,
                        currentBattery: current,
                        energySpent: spent,
                        efficiency: eff,
                        points: pts,
                        xp: xpValue,
                        caffeineLateFlag: caffeine,
                        sleepDebtHours: max(0, snapshot.baseline.sleepDebtHours),
                        batteryIsEstimated: estimated)
    }

    // MARK: - Morning charge (sleep -> battery)

    /// Battery level at wake (0...100). Returns nil only when unauthorized.
    ///
    /// Fallback ladder when no sleep was recorded (watch not worn, etc.):
    /// 1. Estimate the charge from the user's own 7-day average sleep, discounted
    ///    by a confidence factor and still reduced by any tracked sleep debt.
    /// 2. With no usable history either, boot to the neutral default.
    public static func morningBattery(snapshot: HealthSnapshot,
                                      targets: UserTargets) -> Double? {
        guard snapshot.isAuthorized else { return nil }
        guard let sleep = snapshot.sleep else {
            return estimatedMorningBattery(snapshot: snapshot, targets: targets)
        }

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

        // Fatigue trim: sustained training-load spikes cost a bounded few points.
        let fatigue = acwrPenalty(snapshot.baseline)

        let charge = durationCharge * quality * recovery + consistency + regularity - debtPenalty - fatigue
        return clamp(charge, 0, 100)
    }

    /// Estimated charge when no sleep was recorded. Tiered ladder (never assume
    /// zero sleep and never assume a perfect night):
    /// B1. Preferred: the user's typical recent MEASURED morning charge (median),
    ///     minus a flat low-confidence haircut.
    /// B2. Else: the recent average night run through the duration formula,
    ///     discounted for uncertainty.
    /// C.  Brand-new user, no history: neutral-high default, no debt penalty.
    static func estimatedMorningBattery(snapshot: HealthSnapshot,
                                        targets: UserTargets) -> Double {
        if let typical = snapshot.baseline.typicalMorningCharge {
            return clamp(typical - ScoringConstants.sleepFallbackHaircut, 0, 100)
        }
        guard let avg = snapshot.baseline.averageSleepHours, avg >= 1.0 else {
            return ScoringConstants.noDataNeutralBattery
        }
        let target = max(1.0, targets.sleepTargetHours)
        let durationCharge = ScoringConstants.durationChargeMax * min(avg / target, 1.0)
        return clamp(durationCharge * ScoringConstants.sleepFallbackConfidence, 0, 100)
    }

    /// Running-balance sleep debt over recent nights (oldest -> newest), in
    /// hours. Evidence-based shape (Van Dongen 2003 accumulation; RISE-style
    /// backlog): each night the balance first DECAYS (half-life about 4 nights),
    /// then a short night adds its shortfall linearly, while oversleep pays down
    /// at 0.5:1 with at most 2 credited hours per night - one long lie-in cannot
    /// wipe a two-week backlog. Clamped to [0, cap]. Pure and unit-testable.
    /// Callers should EXCLUDE last night (it is already priced into the acute
    /// morning charge).
    public static func sleepDebt(nightlyHours: [Double],
                                 targetHours: Double = ScoringConstants.sleepTargetHours) -> Double {
        var debt = 0.0
        for night in nightlyHours {
            debt *= ScoringConstants.sleepDebtDecayPerNight
            let shortfall = targetHours - night
            if shortfall > 0 {
                debt += shortfall
            } else {
                let credit = min(-shortfall, ScoringConstants.sleepDebtRecoveryCapHours)
                    * ScoringConstants.sleepDebtRecoveryRate
                debt -= credit
            }
            debt = clamp(debt, 0, ScoringConstants.sleepDebtCapHours)
        }
        return debt
    }

    /// Sleep-quality multiplier from efficiency + Deep/REM share. Neutral 1.0
    /// when the device recorded no stages or no in-bed time.
    static func qualityMultiplier(_ sleep: SleepData) -> Double {
        let effRatio = sleep.hasInBed ? sleep.efficiency / ScoringConstants.targetSleepEfficiency : 1.0
        let stageRatio = sleep.hasStages ? sleep.deepRemShare / ScoringConstants.targetDeepRemShare : 1.0
        let raw = 0.5 * effRatio + 0.5 * stageRatio
        return clamp(raw, ScoringConstants.qualityMin, ScoringConstants.qualityMax)
    }

    /// Overnight-recovery multiplier: HRV (higher is better) and resting HR
    /// (lower is better) versus the user's own baseline, then two downside-only
    /// illness guards (elevated wrist temperature, elevated respiratory rate).
    /// The same signal blend Whoop/Oura lean on. Neutral 1.0 when data is absent.
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
        let raw = (0.5 * hrvRatio + 0.5 * rhrRatio) * tempGuard(snapshot) * respGuard(snapshot)
        return clamp(raw, ScoringConstants.recoveryMin, ScoringConstants.recoveryMax)
    }

    /// Downside-only guard: a night noticeably WARMER than the personal baseline
    /// signals illness/poor recovery. Never rewards running cool.
    static func tempGuard(_ snapshot: HealthSnapshot) -> Double {
        guard let temp = snapshot.sleepingWristTempC,
              let base = snapshot.baseline.wristTempBaselineC else { return 1.0 }
        let delta = temp - base
        guard delta > ScoringConstants.tempGuardThresholdC else { return 1.0 }
        let halves = (delta - ScoringConstants.tempGuardThresholdC) / 0.5
        return max(ScoringConstants.tempGuardFloor,
                   1.0 - ScoringConstants.tempGuardPenaltyPerHalfC * halves)
    }

    /// Downside-only guard: overnight breathing meaningfully FASTER than the
    /// personal baseline flags illness/overtraining.
    static func respGuard(_ snapshot: HealthSnapshot) -> Double {
        guard let resp = snapshot.overnightRespiratoryRate,
              let base = snapshot.baseline.respiratoryRateBaseline else { return 1.0 }
        let delta = resp - base
        guard delta > ScoringConstants.respGuardThresholdBPM else { return 1.0 }
        return max(ScoringConstants.respGuardFloor,
                   1.0 - ScoringConstants.respGuardPenaltyPerBPM * (delta - ScoringConstants.respGuardThresholdBPM))
    }

    /// Fatigue trim from the acute:chronic workload ratio (7-day vs 28-day mean
    /// active energy). Spiking training load above the habitual level shaves a
    /// bounded few points off the morning charge, the way Samsung/Oura/Whoop
    /// carry accumulated load. Neutral 0 without both baselines.
    static func acwrPenalty(_ baseline: Baseline) -> Double {
        guard let acute = baseline.averageDailyActiveKcal,
              let chronic = baseline.chronicDailyActiveKcal, chronic > 0 else { return 0 }
        let ratio = acute / chronic
        guard ratio > ScoringConstants.acwrThreshold else { return 0 }
        let span = ScoringConstants.acwrFullPenaltyRatio - ScoringConstants.acwrThreshold
        let fraction = clamp((ratio - ScoringConstants.acwrThreshold) / span, 0, 1)
        return ScoringConstants.acwrMaxPenalty * fraction
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

    // MARK: - Intraday series (charts)

    /// Reconstruct the day's battery/efficiency curves from cumulative activity
    /// checkpoints. Each checkpoint is scored with the SAME engine as the live
    /// number, so the chart and the hero score always agree.
    public static func daySeries(snapshot: HealthSnapshot,
                                 hourly: [HourlyActivity],
                                 targets: UserTargets = .default) -> [EnergySeriesPoint] {
        guard snapshot.isAuthorized else { return [] }
        let wake = snapshot.sleep?.wakeTime ?? startOfDay(snapshot.asOf, fallbackWake: targets.wakeTarget)

        var series: [EnergySeriesPoint] = []
        for point in hourly.sorted(by: { $0.date < $1.date }) {
            guard point.date >= wake, point.date <= snapshot.asOf else { continue }
            var at = snapshot
            at.asOf = point.date
            at.activeEnergyKcal = point.activeEnergyKcal
            at.exerciseMinutes = point.exerciseMinutes
            at.standHours = point.standHours
            at.waterML = point.waterML
            let score = score(at, targets: targets)
            series.append(EnergySeriesPoint(date: point.date,
                                            battery: score.currentBattery ?? 0,
                                            efficiency: score.efficiency ?? 0,
                                            energySpent: score.energySpent,
                                            points: score.points.total))
        }
        return series
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
    /// Derive a compact, persistable record for one day from its full score.
    public static func dailyProgress(from day: DayScore) -> DailyProgress {
        let pointsMet = day.points.maxAvailable > 0
            && day.points.total >= 0.7 * day.points.maxAvailable
        let sleepMet = day.hasSleepData && (day.morningBattery ?? 0) >= 70
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return DailyProgress(date: cal.startOfDay(for: day.date),
                             points: day.points.total, xp: day.xp,
                             pointsGoalMet: pointsMet, sleepGoalMet: sleepMet)
    }

    /// Lifetime progression from the user's persisted daily records. XP is the
    /// running sum over ALL days, so level climbs forever; streaks are date-aware,
    /// so a missing or unmet calendar day ends the run.
    public static func progression(from days: [DailyProgress]) -> Progression {
        let totalXP = days.reduce(0) { $0 + $1.xp }
        let lvl = level(forXP: totalXP)
        let floorXP = xpThreshold(forLevel: lvl)
        let nextXP = xpThreshold(forLevel: lvl + 1)

        return Progression(
            level: lvl, totalXP: totalXP,
            xpIntoLevel: totalXP - floorXP, xpForNextLevel: nextXP - floorXP,
            pointsStreak: currentStreak(days) { $0.pointsGoalMet },
            sleepStreak: currentStreak(days) { $0.sleepGoalMet },
            longestPointsStreak: longestStreak(days) { $0.pointsGoalMet },
            longestSleepStreak: longestStreak(days) { $0.sleepGoalMet })
    }

    /// Backward-compatible overload over DayScores (maps to DailyProgress first).
    public static func progression(history: [DayScore]) -> Progression {
        progression(from: history.map(dailyProgress(from:)))
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

    /// Consecutive calendar days up to the most recent record that meet the bar.
    /// A missing day or an unmet PAST day ends the streak. The most recent record
    /// (today, still in progress) counts when met but never BREAKS the run -
    /// otherwise every streak would read 0 each morning until the bar is re-hit.
    static func currentStreak(_ days: [DailyProgress], met: (DailyProgress) -> Bool) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        var byDay: [Date: DailyProgress] = [:]
        for d in days { byDay[cal.startOfDay(for: d.date)] = d }
        guard var cursor = byDay.keys.max() else { return 0 }
        var streak = 0
        // Today in progress: skip it (without breaking) unless already met.
        if let today = byDay[cursor], !met(today) {
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = prev
        }
        while let rec = byDay[cursor], met(rec) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// The longest run of consecutive calendar days meeting the bar, across all history.
    static func longestStreak(_ days: [DailyProgress], met: (DailyProgress) -> Bool) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let sorted = days
            .map { (day: cal.startOfDay(for: $0.date), rec: $0) }
            .sorted { $0.day < $1.day }
        var longest = 0, run = 0
        var prev: Date? = nil
        for item in sorted {
            let consecutive = prev.map {
                cal.dateComponents([.day], from: $0, to: item.day).day == 1
            } ?? false
            if met(item.rec) {
                run = (consecutive && run > 0) ? run + 1 : 1
            } else {
                run = 0
            }
            longest = max(longest, run)
            prev = item.day
        }
        return longest
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
