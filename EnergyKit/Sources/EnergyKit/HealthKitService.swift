#if os(iOS)
import Foundation
import HealthKit

/// Reads live Apple Health data and assembles a `HealthSnapshot` for the engine.
///
/// Privacy: read-only. No share/write scopes are ever requested, nothing is
/// persisted, and no data leaves the device. Each call queries HealthKit fresh
/// and returns an in-memory snapshot that the caller is free to discard.
@available(iOS 17.0, *)
public actor HealthKitService {

    public static let shared = HealthKitService()
    private let store = HKHealthStore()

    public init() {}

    public nonisolated var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // MARK: Authorization

    /// The complete set of read-only types Amperly uses.
    private var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.stepCount),
            HKQuantityType(.dietaryWater),
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.dietaryCaffeine),
            HKQuantityType(.timeInDaylight),
            HKCategoryType(.sleepAnalysis),
            HKCategoryType(.appleStandHour),
            HKObjectType.workoutType(),
            HKObjectType.activitySummaryType()
        ]
        types = types.filter { _ in true }
        return types
    }

    /// Request read access. Apple never reveals whether read access was granted,
    /// so callers should attempt a query and treat empty results as "no data".
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Whether the user has been asked yet. Used only to drive the onboarding
    /// prompt; it is not a guarantee of read access.
    public func hasRequestedAuthorization() -> Bool {
        store.authorizationStatus(for: HKCategoryType(.sleepAnalysis)) != .notDetermined
    }

    // MARK: Snapshot assembly

    /// Build a full snapshot for "now". Returns an unauthorized snapshot if
    /// HealthKit is unavailable on the device.
    public func currentSnapshot(targets: UserTargets = .default, now: Date = Date()) async -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else {
            return HealthSnapshot(isAuthorized: false, asOf: now)
        }

        async let sleepInfo = mainSleepSession(now: now)
        async let active = sumToday(.activeEnergyBurned, unit: .kilocalorie(), now: now)
        async let basal = sumToday(.basalEnergyBurned, unit: .kilocalorie(), now: now)
        async let exercise = sumToday(.appleExerciseTime, unit: .minute(), now: now)
        async let steps = sumToday(.stepCount, unit: .count(), now: now)
        async let water = sumToday(.dietaryWater, unit: HKUnit.literUnit(with: .milli), now: now)
        async let stand = standHoursToday(now: now)
        async let hrv = latestValue(.heartRateVariabilitySDNN,
                                     unit: HKUnit.secondUnit(with: .milli),
                                     since: now.addingTimeInterval(-36 * 3600))
        async let rhr = latestValue(.restingHeartRate,
                                    unit: HKUnit.count().unitDivided(by: .minute()),
                                    since: now.addingTimeInterval(-48 * 3600))
        async let daylight = sumToday(.timeInDaylight, unit: .minute(), now: now)
        async let caffeine = lastCaffeineDate(now: now)
        async let summary = activitySummary(now: now)
        async let todaysWorkouts = workoutsToday(now: now)
        async let base = baseline(now: now)

        let sleep = await sleepInfo
        let goals = await summary
        let workouts = await todaysWorkouts
        let elevatedMinutes = workouts.reduce(0) { $0 + $1.minutes }

        return HealthSnapshot(
            isAuthorized: true,
            sleep: sleep,
            activeEnergyKcal: await active,
            basalEnergyKcal: await basal,
            steps: Int(await steps),
            exerciseMinutes: await exercise,
            standHours: await stand,
            moveGoalKcal: goals.move,
            exerciseGoalMinutes: goals.exercise,
            standGoalHours: goals.stand,
            hrvSDNN: await hrv,
            restingHeartRate: await rhr,
            waterML: await water,
            timeInDaylightMinutes: await daylight,
            elevatedHeartRateMinutes: elevatedMinutes > 0 ? elevatedMinutes : nil,
            lastCaffeine: await caffeine,
            workouts: workouts,
            baseline: await base,
            asOf: now
        )
    }

    // MARK: Today sums

    private func sumToday(_ id: HKQuantityTypeIdentifier, unit: HKUnit, now: Date) async -> Double {
        let type = HKQuantityType(id)
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func latestValue(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date) async -> Double? {
        let type = HKQuantityType(id)
        let predicate = HKQuery.predicateForSamples(withStart: since, end: nil, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: sort) { _, samples, _ in
                guard let s = samples?.first as? HKQuantitySample else { cont.resume(returning: nil); return }
                cont.resume(returning: s.quantity.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    private func standHoursToday(now: Date) async -> Double {
        let type = HKCategoryType(.appleStandHour)
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let stood = (samples as? [HKCategorySample] ?? [])
                    .filter { $0.value == HKCategoryValueAppleStandHour.stood.rawValue }
                    .count
                cont.resume(returning: Double(stood))
            }
            store.execute(q)
        }
    }

    private func lastCaffeineDate(now: Date) async -> Date? {
        let type = HKQuantityType(.dietaryCaffeine)
        let predicate = HKQuery.predicateForSamples(withStart: now.addingTimeInterval(-18 * 3600), end: now, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: sort) { _, samples, _ in
                cont.resume(returning: samples?.first?.endDate)
            }
            store.execute(q)
        }
    }

    // MARK: Sleep

    /// The main sleep session: the asleep segments overlapping last night,
    /// summed by stage, with bedtime = first asleep start and wake = last asleep end.
    private func mainSleepSession(now: Date) async -> SleepData? {
        let type = HKCategoryType(.sleepAnalysis)
        // Look back from ~18:00 yesterday through now to capture last night.
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: now)
        let windowStart = cal.date(byAdding: .hour, value: -6, to: todayStart) ?? todayStart.addingTimeInterval(-21600)
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: now, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, samples, _ in
                cont.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        guard !samples.isEmpty else { return nil }

        func value(_ s: HKCategorySample) -> HKCategoryValueSleepAnalysis? {
            HKCategoryValueSleepAnalysis(rawValue: s.value)
        }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        let asleepSamples = samples.filter { asleepValues.contains($0.value) }
        guard !asleepSamples.isEmpty else { return nil }

        func duration(_ arr: [HKCategorySample]) -> TimeInterval {
            arr.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        }
        let deep = duration(asleepSamples.filter { value($0) == .asleepDeep })
        let rem = duration(asleepSamples.filter { value($0) == .asleepREM })
        let core = duration(asleepSamples.filter { value($0) == .asleepCore })
        let asleep = duration(asleepSamples)
        let inBed = duration(samples.filter { value($0) == .inBed })
        let awake = duration(samples.filter { value($0) == .awake })

        let bedTime = asleepSamples.map(\.startDate).min() ?? windowStart
        let wakeTime = asleepSamples.map(\.endDate).max() ?? now

        // Ignore naps: require at least 1h of asleep time for a "main" session.
        guard asleep >= 3600 else { return nil }

        return SleepData(inBed: max(inBed, asleep), asleep: asleep, deep: deep, rem: rem, core: core,
                         awake: awake, bedTime: bedTime, wakeTime: wakeTime)
    }

    // MARK: Activity summary (ring goals)

    private func activitySummary(now: Date) async -> (move: Double?, exercise: Double?, stand: Double?) {
        let cal = Calendar(identifier: .gregorian)
        var comps = cal.dateComponents([.year, .month, .day], from: now)
        comps.calendar = cal
        let predicate = HKQuery.predicate(forActivitySummariesBetweenStart: comps, end: comps)
        let summary: HKActivitySummary? = await withCheckedContinuation { cont in
            let q = HKActivitySummaryQuery(predicate: predicate) { _, summaries, _ in
                cont.resume(returning: summaries?.first)
            }
            store.execute(q)
        }
        guard let s = summary else { return (nil, nil, nil) }
        let move = s.activeEnergyBurnedGoal.doubleValue(for: .kilocalorie())
        let exercise = s.exerciseTimeGoal?.doubleValue(for: .minute())
            ?? s.appleExerciseTimeGoal.doubleValue(for: .minute())
        let stand = s.standHoursGoal?.doubleValue(for: .count())
            ?? s.appleStandHoursGoal.doubleValue(for: .count())
        return (move > 0 ? move : nil, exercise, stand)
    }

    // MARK: Workouts

    private func workoutsToday(now: Date) async -> [WorkoutSummary] {
        let start = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: .strictStartDate)
        let workouts: [HKWorkout] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: .workoutType(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                cont.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(q)
        }
        return workouts.map { w in
            let kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
            return WorkoutSummary(start: w.startDate, end: w.endDate, activeEnergyKcal: kcal)
        }
    }

    // MARK: Rolling baselines (live, never stored)

    private func baseline(now: Date) async -> Baseline {
        async let activeAvg = dailyAverage(.activeEnergyBurned, unit: .kilocalorie(), days: 7, now: now)
        async let basalAvg = dailyAverage(.basalEnergyBurned, unit: .kilocalorie(), days: 7, now: now)
        async let hrvAvg = discreteAverage(.heartRateVariabilitySDNN,
                                           unit: HKUnit.secondUnit(with: .milli), days: 14, now: now)
        async let rhrAvg = discreteAverage(.restingHeartRate,
                                           unit: HKUnit.count().unitDivided(by: .minute()), days: 14, now: now)
        async let sleepStats = sleepBaseline(days: 7, now: now)

        let s = await sleepStats
        return Baseline(averageSleepHours: s.averageHours,
                        hrvBaseline: await hrvAvg,
                        restingHeartRateBaseline: await rhrAvg,
                        sleepConsistencySDMinutes: s.consistencySDMinutes,
                        averageDailyActiveKcal: await activeAvg,
                        dailyBasalKcal: await basalAvg,
                        sleepDebtHours: s.debtHours)
    }

    private func dailyAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, now: Date) async -> Double? {
        let type = HKQuantityType(id)
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: now)
        guard let start = cal.date(byAdding: .day, value: -days, to: anchor) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: anchor, options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: .cumulativeSum, anchorDate: anchor,
                                                intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, collection, _ in
                guard let collection else { cont.resume(returning: nil); return }
                var total = 0.0, count = 0
                collection.enumerateStatistics(from: start, to: anchor) { stat, _ in
                    if let sum = stat.sumQuantity()?.doubleValue(for: unit), sum > 0 {
                        total += sum; count += 1
                    }
                }
                cont.resume(returning: count > 0 ? total / Double(count) : nil)
            }
            store.execute(q)
        }
    }

    private func discreteAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, now: Date) async -> Double? {
        let type = HKQuantityType(id)
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: now)
        guard let start = cal.date(byAdding: .day, value: -days, to: anchor) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
                cont.resume(returning: stats?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    /// Average nightly sleep, bedtime-consistency SD, and accumulated sleep debt
    /// over the last `days` nights.
    private func sleepBaseline(days: Int, now: Date) async -> (averageHours: Double?, consistencySDMinutes: Double?, debtHours: Double) {
        let type = HKCategoryType(.sleepAnalysis)
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: now)
        guard let start = cal.date(byAdding: .day, value: -(days + 1), to: anchor) else { return (nil, nil, 0) }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { _, s, _ in
                cont.resume(returning: (s as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]
        // Group asleep time and bedtime by the night's wake-day.
        var hoursByDay: [Date: Double] = [:]
        var bedMinutesByDay: [Date: Int] = [:]
        for s in samples where asleepValues.contains(s.value) {
            let day = cal.startOfDay(for: s.endDate)
            hoursByDay[day, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 3600.0
            let bedComps = cal.dateComponents([.hour, .minute], from: s.startDate)
            let bedMin = (bedComps.hour ?? 0) * 60 + (bedComps.minute ?? 0)
            // Keep the earliest bedtime for the night.
            if let existing = bedMinutesByDay[day] { bedMinutesByDay[day] = min(existing, bedMin) }
            else { bedMinutesByDay[day] = bedMin }
        }
        let nights = hoursByDay.values.filter { $0 >= 1.0 }
        guard !nights.isEmpty else { return (nil, nil, 0) }
        let avg = nights.reduce(0, +) / Double(nights.count)
        let debt = nights.reduce(0.0) { $0 + max(0, ScoringConstants.sleepTargetHours - $1) }

        // Bedtime consistency: SD of bedtime-minutes (shifted to handle after-midnight).
        let bedValues = bedMinutesByDay.values.map { $0 > 720 ? $0 - 1440 : $0 } // wrap late-night to negative
        var sd: Double? = nil
        if bedValues.count >= 3 {
            let mean = Double(bedValues.reduce(0, +)) / Double(bedValues.count)
            let variance = bedValues.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(bedValues.count)
            sd = variance.squareRoot()
        }
        return (avg, sd, debt)
    }
}
#endif
