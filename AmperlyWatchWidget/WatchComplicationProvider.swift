//
//  WatchComplicationProvider.swift
//  AmperlyWatchWidget
//

import WidgetKit
import EnergyKit
import Foundation

struct WatchEntry: TimelineEntry {
    let date: Date
    let score: DayScore
}

struct WatchProvider: TimelineProvider {

    func placeholder(in context: Context) -> WatchEntry {
        WatchEntry(date: Date(), score: Self.sample())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        if context.isPreview {
            completion(WatchEntry(date: Date(), score: Self.sample()))
            return
        }
        Task {
            let now = Date()
            completion(WatchEntry(date: now, score: await Self.liveScore(now: now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        Task {
            let now = Date()
            let entry = WatchEntry(date: now, score: await Self.liveScore(now: now))
            // Complications refresh on a tight budget; ask again in ~20 minutes.
            completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(20 * 60))))
        }
    }

    static func liveScore(now: Date) async -> DayScore {
        let snapshot = await HealthKitService.shared.currentSnapshot(now: now)
        return snapshot.isAuthorized ? ScoringEngine.score(snapshot) : .unauthorized(date: now)
    }

    static func sample() -> DayScore {
        DayScore(
            date: Date(), isAuthorized: true, hasSleepData: true,
            morningBattery: 88, currentBattery: 64, energySpent: 24, efficiency: 82,
            points: PointsBreakdown(move: 19, exercise: 14, stand: 12,
                                    bedtime: 9, wake: 8, hydration: 15,
                                    sleepPointsAvailable: true),
            xp: 96, caffeineLateFlag: false
        )
    }
}
