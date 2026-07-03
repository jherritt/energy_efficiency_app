//
//  Provider.swift
//  AmperlyWidget
//
//  Timeline provider for all Amperly widgets. Reads Apple Health LIVE (ephemeral)
//  via EnergyKit's HealthKitService, computes a DayScore on-device with
//  ScoringEngine, and projects the battery forward over the next few hours so the
//  small/medium and lock-screen widgets stay fresh between refreshes.
//
//  Privacy: nothing is persisted or transmitted. Each timeline is built from a
//  single live snapshot held in memory only for the duration of the build.
//

import WidgetKit
import EnergyKit
import Foundation

// MARK: - Entry

/// A single timeline entry. Holds the computed score for its `date`, today's
/// intraday efficiency series (for the large family's chart), plus a flag so
/// placeholder/snapshot renders can show calm sample data in the gallery.
struct AmperlyEntry: TimelineEntry {
    let date: Date
    let score: DayScore
    /// Today's intraday curve, same engine as the hero numbers. Empty when
    /// unauthorized or not yet fetched.
    var series: [EnergySeriesPoint] = []
    var isPlaceholder: Bool = false
}

// MARK: - Provider

struct AmperlyProvider: TimelineProvider {

    /// Refresh cadence; WidgetKit coalesces but we ask for ~20 min.
    private let refreshInterval: TimeInterval = 20 * 60
    /// How far ahead we project battery drain, and at what step.
    private let projectionHorizon: TimeInterval = 2 * 60 * 60
    private let projectionStep: TimeInterval = 30 * 60

    // MARK: TimelineProvider

    func placeholder(in context: Context) -> AmperlyEntry {
        let now = Date()
        return AmperlyEntry(date: now, score: Self.sampleScore(now: now),
                            series: Self.sampleSeries(now: now), isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (AmperlyEntry) -> Void) {
        // The widget gallery preview is allowed to be a sample so it always
        // looks alive even without Health access.
        if context.isPreview {
            let now = Date()
            completion(AmperlyEntry(date: now, score: Self.sampleScore(now: now),
                                    series: Self.sampleSeries(now: now), isPlaceholder: true))
            return
        }
        Task {
            let now = Date()
            let score = await Self.liveScore(now: now)
            completion(AmperlyEntry(date: now, score: score))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AmperlyEntry>) -> Void) {
        let horizon = projectionHorizon
        let step = projectionStep
        let refresh = refreshInterval
        Task {
            // Hard time-box: a widget process gets a small budget, and a single
            // stalled HealthKit query would otherwise leave the widget as a dead
            // placeholder forever (completion never called). Whichever finishes
            // first wins; on timeout we ship a degraded-but-valid timeline that
            // retries soon.
            let now = Date()
            let timeline = await withTaskGroup(of: Timeline<AmperlyEntry>?.self) { group in
                group.addTask {
                    await Self.liveTimeline(now: now, horizon: horizon, step: step, refresh: refresh)
                }
                group.addTask {
                    try? await Task.sleep(nanoseconds: 12_000_000_000)
                    return nil
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            if let timeline {
                completion(timeline)
            } else {
                let entry = AmperlyEntry(date: now, score: .unauthorized(date: now))
                completion(Timeline(entries: [entry],
                                    policy: .after(now.addingTimeInterval(10 * 60))))
            }
        }
    }

    /// The real timeline: live snapshot, intraday series, forward projections.
    private static func liveTimeline(now: Date, horizon: TimeInterval, step: TimeInterval,
                                     refresh: TimeInterval) async -> Timeline<AmperlyEntry> {
        let snapshot = await HealthKitService.shared.currentSnapshot(now: now)

        // Unauthorized: a single "--" entry, retry on the normal cadence.
        guard snapshot.isAuthorized else {
            let entry = AmperlyEntry(date: now, score: .unauthorized(date: now))
            return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(refresh)))
        }

        // Fetch today's cumulative activity checkpoints ONCE and derive the
        // intraday efficiency curve with the same engine as the hero numbers.
        // Projected future entries reuse the curve computed at `now`.
        let hourly = await HealthKitService.shared.todayHourlyActivity(now: now)
        let series = ScoringEngine.daySeries(snapshot: snapshot, hourly: hourly)

        // Project the same live snapshot forward by advancing `asOf`. Reusing
        // one snapshot keeps everything ephemeral (no extra HealthKit reads)
        // while the battery visibly drains across the next couple of hours.
        var entries: [AmperlyEntry] = []
        var t: TimeInterval = 0
        while t <= horizon {
            let futureDate = now.addingTimeInterval(t)
            var projected = snapshot
            projected.asOf = futureDate
            let score = ScoringEngine.score(projected)
            entries.append(AmperlyEntry(date: futureDate, score: score, series: series))
            t += step
        }
        if entries.isEmpty {
            entries.append(AmperlyEntry(date: now, score: ScoringEngine.score(snapshot),
                                        series: series))
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(refresh)))
    }

    // MARK: Scoring helpers

    /// Compute a live score from a fresh, ephemeral snapshot.
    static func liveScore(now: Date) async -> DayScore {
        let snapshot = await HealthKitService.shared.currentSnapshot(now: now)
        guard snapshot.isAuthorized else { return .unauthorized(date: now) }
        return ScoringEngine.score(snapshot)
    }

    /// A calm, representative sample for placeholders/previews (never real data).
    static func sampleScore(now: Date) -> DayScore {
        let points = PointsBreakdown(move: 19, exercise: 14, stand: 12,
                                     bedtime: 9, wake: 8, hydration: 15,
                                     sleepPointsAvailable: true)
        return DayScore(
            date: now,
            isAuthorized: true,
            hasSleepData: true,
            morningBattery: 88,
            currentBattery: 64,
            energySpent: 24,
            efficiency: 82,
            points: points,
            xp: 96,
            caffeineLateFlag: false
        )
    }

    /// A plausible fabricated intraday curve for placeholders/previews (never
    /// real data). Eight points from a 7 AM wake: battery drains toward the
    /// sample's 64%, efficiency climbs toward the sample's 82.
    static func sampleSeries(now: Date) -> [EnergySeriesPoint] {
        let wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: now)
            ?? now.addingTimeInterval(-8 * 60 * 60)
        let batteries: [Double] = [88, 85, 81, 78, 74, 70, 67, 64]
        let efficiencies: [Double] = [70, 73, 76, 78, 77, 80, 81, 82]
        return (0..<8).map { i in
            EnergySeriesPoint(
                date: wake.addingTimeInterval(Double(i) * 90 * 60),
                battery: batteries[i],
                efficiency: efficiencies[i],
                energySpent: 88 - batteries[i],
                points: Double(i) * 9.5
            )
        }
    }
}
