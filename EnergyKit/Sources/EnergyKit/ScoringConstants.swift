import Foundation

/// All tunable constants for Amperly's scoring engine in one place.
///
/// Every value here is a plain multiplier or threshold so the whole model can be
/// re-derived by hand. The engine is intentionally transparent: a user (or a
/// reviewer) can reproduce any number Amperly shows with these constants and a
/// calculator. Nothing here depends on HealthKit, so this file (and the whole
/// scoring core) compiles and unit-tests on any platform.
public enum ScoringConstants {

    // MARK: Sleep target

    /// Default nightly sleep target in hours (user-configurable 7...9).
    public static let sleepTargetHours: Double = 8.0

    // MARK: Morning charge (sleep -> battery)

    /// Maximum battery points from sleep duration alone.
    public static let durationChargeMax: Double = 85.0
    /// Boot floor: any real sleep (>= 1h) still charges at least this much.
    public static let durationFloorIfAsleep: Double = 10.0
    /// Maximum schedule-consistency bonus (on-time bed + wake).
    public static let consistencyBonusMax: Double = 15.0
    /// Maximum 7-day regularity bonus (low variance in bed/wake times).
    public static let regularityBonusMax: Double = 5.0

    /// On-time tolerance: <= this many minutes off target counts as fully on time.
    public static let onTimeToleranceMin: Double = 30.0
    /// Zero-credit point: >= this many minutes off target earns nothing.
    public static let onTimeZeroMin: Double = 90.0

    // MARK: Sleep quality + recovery multipliers (enhancements)

    /// Sleep-quality multiplier bounds (stages + efficiency). 1.0 == neutral.
    public static let qualityMin: Double = 0.85
    public static let qualityMax: Double = 1.08
    /// Overnight-recovery multiplier bounds (HRV + resting HR + temperature +
    /// respiration). 1.0 == neutral. Widened so autonomic recovery carries real
    /// weight, in line with Whoop/Oura/Fitbit practice.
    public static let recoveryMin: Double = 0.88
    public static let recoveryMax: Double = 1.10

    // MARK: Illness guards (downside-only; neutral when data is absent)

    /// Overnight wrist temperature this far above the personal baseline (deg C)
    /// starts the guard; each further 0.5 C costs 3%, floored below.
    public static let tempGuardThresholdC: Double = 0.5
    public static let tempGuardPenaltyPerHalfC: Double = 0.03
    public static let tempGuardFloor: Double = 0.90
    /// Overnight respiratory rate this many breaths/min above baseline starts
    /// the guard; each further breath costs 2%, floored below.
    public static let respGuardThresholdBPM: Double = 1.5
    public static let respGuardPenaltyPerBPM: Double = 0.02
    public static let respGuardFloor: Double = 0.90

    // MARK: Training load (acute:chronic workload ratio)

    /// 7-day vs 28-day active-energy ratio above this indicates spiking load...
    public static let acwrThreshold: Double = 1.3
    /// ...reaching the full penalty at this ratio.
    public static let acwrFullPenaltyRatio: Double = 1.7
    /// Cap on the fatigue trim taken off the morning charge.
    public static let acwrMaxPenalty: Double = 5.0
    /// Reference targets where the multipliers sit at 1.0.
    public static let targetSleepEfficiency: Double = 0.90
    public static let targetDeepRemShare: Double = 0.40

    // MARK: Multi-day sleep debt

    /// Battery points subtracted per hour of accumulated sleep debt.
    /// (2%/h so the cap is reserved for genuinely severe backlog; RISE's 5h
    /// "healthy ceiling" lands at a moderate 10-point hit.)
    public static let debtPenaltyPerHour: Double = 2.0
    /// Cap on the total sleep-debt penalty.
    public static let debtPenaltyMax: Double = 15.0
    /// Cap on the tracked sleep-debt balance itself (hours).
    public static let sleepDebtCapHours: Double = 20.0
    /// Nights in the debt window (Van Dongen 2003 accumulation horizon).
    public static let sleepDebtWindowNights: Int = 14
    /// Passive nightly decay of the debt balance (half-life about 4 nights).
    public static let sleepDebtDecayPerNight: Double = 0.84
    /// Oversleep pays debt down at this rate (asymmetric recovery)...
    public static let sleepDebtRecoveryRate: Double = 0.5
    /// ...and at most this many oversleep hours count per night (no binge repay).
    public static let sleepDebtRecoveryCapHours: Double = 2.0

    // MARK: Sleep fallback (no sleep recorded)

    /// Confidence discount applied when the estimate must come from average
    /// sleep HOURS (no charge history available).
    public static let sleepFallbackConfidence: Double = 0.85
    /// Flat low-confidence haircut when estimating from the user's typical
    /// recent morning charge (the preferred fallback).
    public static let sleepFallbackHaircut: Double = 5.0
    /// Morning battery when there is no sleep data AND no usable history.
    /// Leaders start neutral-high: assume sleep need met, do not penalize a
    /// brand-new user for having no history.
    public static let noDataNeutralBattery: Double = 72.0

    // MARK: Drain (battery depletion across the waking day)

    /// Baseline cost of simply being awake, in battery-% per hour.
    /// Calibrated so a 16h waking day burns ~48% on baseline alone.
    public static let baselineDrainPerHour: Double = 3.0
    /// Activity cost in battery-% per active kcal.
    /// Calibrated so a full 500 kcal Move goal costs ~30%.
    public static let activityDrainPerKcal: Double = 0.06
    /// Reference basal metabolic rate (kcal/day) where personalization is neutral.
    public static let referenceBasalKcal: Double = 1600.0
    /// Clamp on the personalized baseline drain rate.
    public static let baselineRateMin: Double = 2.0
    public static let baselineRateMax: Double = 4.5
    /// Maximum intensity multiplier from sustained elevated heart-rate time.
    public static let intensityMax: Double = 1.15
    /// Maximum drain relief from daytime daylight exposure (alertness boost).
    public static let daylightReliefMax: Double = 0.05
    /// Minutes of daylight that earn the full relief.
    public static let daylightFullReliefMinutes: Double = 60.0

    // MARK: Energy budget + efficiency

    /// Daily energy budget D in battery-% (one standard full day:
    /// 16h baseline 48% + 500 kcal Move 30% = 78%). The efficiency denominator.
    public static let dailyEnergyBudget: Double = 78.0
    /// Small-denominator floor that tames the hero number right after waking.
    public static let efficiencyFloor: Double = 8.0

    // MARK: Points ledger (max 100/day)

    public static let movePointsMax: Double = 25.0
    public static let exercisePointsMax: Double = 20.0
    public static let standPointsMax: Double = 15.0
    public static let bedtimePointsMax: Double = 10.0
    public static let wakePointsMax: Double = 10.0
    public static let hydrationPointsMax: Double = 20.0
    public static let totalPointsWithSleep: Double = 100.0
    /// When no sleep is detected, bedtime+wake (20 pts) drop out of both the
    /// earned total and the available total so efficiency stays honest.
    public static let totalPointsNoSleep: Double = 80.0

    // MARK: Activity-ring goal defaults (used only if Apple goals are unavailable)

    public static let defaultMoveGoalKcal: Double = 500.0
    public static let defaultExerciseGoalMin: Double = 30.0
    public static let defaultStandGoalHours: Double = 12.0
    public static let defaultWaterGoalML: Double = 2000.0

    // MARK: Difficulty weighting + levels (gamification XP only; never affects efficiency)

    /// Difficulty weight bounds. A goal the user usually misses is worth more XP.
    public static let difficultyWeightMin: Double = 1.0
    public static let difficultyWeightMax: Double = 1.3
    /// Base XP step; level L is reached at cumulative XP >= base * L*(L+1)/2.
    public static let xpPerLevelBase: Double = 400.0

    // MARK: Caffeine

    /// Caffeine consumed within this many hours of target bedtime is flagged.
    public static let caffeineCutoffHoursBeforeBed: Double = 6.0
}
