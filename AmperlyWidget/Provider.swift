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

/// A single timeline entry. Holds the computed score for its `date` plus a flag
/// so placeholder/snapshot renders can show calm sample data in the gallery.
struct AmperlyEntry: TimelineEntry {
    let date: Date
    let score: DayScore
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
        AmperlyEntry(date: Date(), score: Self.sampleScore(now: Date()), isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (AmperlyEntry) -> Void) {
        // The widget gallery preview is allowed to be a sample so it always
        // looks alive even without Health access.
        if context.isPreview {
            completion(AmperlyEntry(date: Date(), score: Self.sampleScore(now: Date()), isPlaceholder: true))
            return
        }
        Task {
            let now = Date()
            let score = await Self.liveScore(now: now)
            completion(AmperlyEntry(date: now, score: score))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AmperlyEntry>) -> Void) {
        Task {
            let now = Date()
            let snapshot = await HealthKitService.shared.currentSnapshot(now: now)

            // Unauthorized: a single "--" entry, retry on the normal cadence.
            guard snapshot.isAuthorized else {
                let entry = AmperlyEntry(date: now, score: .unauthorized(date: now))
                let timeline = Timeline(entries: [entry],
                                        policy: .after(now.addingTimeInterval(refreshInterval)))
                completion(timeline)
                return
            }

            // Project the same live snapshot forward by advancing `asOf`. Reusing
            // one snapshot keeps everything ephemeral (no extra HealthKit reads)
            // while the battery visibly drains across the next couple of hours.
            var entries: [AmperlyEntry] = []
            var t: TimeInterval = 0
            while t <= projectionHorizon {
                let futureDate = now.addingTimeInterval(t)
                var projected = snapshot
                projected.asOf = futureDate
                let score = ScoringEngine.score(projected)
                entries.append(AmperlyEntry(date: futureDate, score: score))
                t += projectionStep
            }
            if entries.isEmpty {
                entries.append(AmperlyEntry(date: now, score: ScoringEngine.score(snapshot)))
            }

            let timeline = Timeline(entries: entries,
                                    policy: .after(now.addingTimeInterval(refreshInterval)))
            completion(timeline)
        }
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
}
