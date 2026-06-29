//
//  ProgressionStore.swift
//  Amperly
//
//  On-device, private store for lifetime gamification progress (points, XP, level,
//  streaks). SwiftData only - one small row per day, never transmitted, no account.
//  This is derived data (no raw health records), so the App Privacy label stays
//  "Data Not Collected." It lets levels and streaks accumulate for months and years.
//

import Foundation
import SwiftData
import EnergyKit

/// One persisted day of progress. Keyed uniquely by the day's start.
@Model
final class DayRecord {
    @Attribute(.unique) var dayStart: Date
    var points: Double
    var xp: Double
    var pointsGoalMet: Bool
    var sleepGoalMet: Bool

    init(dayStart: Date, points: Double, xp: Double, pointsGoalMet: Bool, sleepGoalMet: Bool) {
        self.dayStart = dayStart
        self.points = points
        self.xp = xp
        self.pointsGoalMet = pointsGoalMet
        self.sleepGoalMet = sleepGoalMet
    }

    var asDailyProgress: DailyProgress {
        DailyProgress(date: dayStart, points: points, xp: xp,
                      pointsGoalMet: pointsGoalMet, sleepGoalMet: sleepGoalMet)
    }
}

@MainActor
final class ProgressionStore {

    static let shared = ProgressionStore()

    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: DayRecord.self)
        } catch {
            // Never crash the app over progression storage; degrade to in-memory.
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try! ModelContainer(for: DayRecord.self, configurations: config)
        }
    }

    private var context: ModelContext { container.mainContext }

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal
    }

    /// True when nothing has been recorded yet (drives the one-time backfill).
    var isEmpty: Bool {
        ((try? context.fetchCount(FetchDescriptor<DayRecord>())) ?? 0) == 0
    }

    /// Insert or update the row for a day (no save).
    private func upsert(_ daily: DailyProgress) {
        let day = calendar.startOfDay(for: daily.date)
        let descriptor = FetchDescriptor<DayRecord>(predicate: #Predicate { $0.dayStart == day })
        if let existing = try? context.fetch(descriptor).first {
            existing.points = daily.points
            existing.xp = daily.xp
            existing.pointsGoalMet = daily.pointsGoalMet
            existing.sleepGoalMet = daily.sleepGoalMet
        } else {
            context.insert(DayRecord(dayStart: day, points: daily.points, xp: daily.xp,
                                     pointsGoalMet: daily.pointsGoalMet, sleepGoalMet: daily.sleepGoalMet))
        }
    }

    /// Record (upsert) a single day and persist.
    func record(_ daily: DailyProgress) {
        upsert(daily)
        try? context.save()
    }

    /// Record many days in one transaction (used for the first-run backfill).
    func recordAll(_ dailies: [DailyProgress]) {
        for d in dailies { upsert(d) }
        try? context.save()
    }

    /// All stored days as DailyProgress, oldest to newest.
    func allDays() -> [DailyProgress] {
        let descriptor = FetchDescriptor<DayRecord>(sortBy: [SortDescriptor(\.dayStart, order: .forward)])
        return ((try? context.fetch(descriptor)) ?? []).map(\.asDailyProgress)
    }
}
