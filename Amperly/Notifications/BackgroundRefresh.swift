//
//  BackgroundRefresh.swift
//  Amperly
//
//  Opportunistic background refresh so the low-efficiency nudge is evaluated
//  even when the app has not been opened. iOS grants these windows at its own
//  discretion (typically a handful per day for an app the user actually uses),
//  which is exactly the cadence a once-a-day nudge needs.
//
//  Privacy unchanged: the handler reads Apple Health, computes in memory,
//  schedules or cancels a local notification, and exits. Nothing is stored.
//

import Foundation
import BackgroundTasks
import EnergyKit

enum BackgroundRefresh {

    /// Must match BGTaskSchedulerPermittedIdentifiers in Info.plist.
    static let taskIdentifier = "com.amperly.Amperly.refresh"

    /// Register the handler. Call exactly once, before the app finishes launching.
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refresh)
        }
    }

    /// Ask for the next window (~2h out; iOS decides the actual timing). Safe to
    /// call repeatedly - duplicate submissions replace the pending request.
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 2 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        // Always keep the chain alive first: reschedule the next window.
        schedule()

        let work = Task {
            defer { task.setTaskCompleted(success: true) }
            guard UserDefaults.standard.bool(forKey: "lowEfficiencyNudgeEnabled") else { return }

            let snapshot = await HealthKitService.shared.currentSnapshot()
            guard snapshot.isAuthorized else { return }
            let score = ScoringEngine.score(snapshot)
            await NotificationManager.shared.refreshLowEfficiencyNudge(
                isEnabled: true,
                efficiency: score.efficiency,
                energySpent: score.energySpent,
                pointsEarned: score.points.total)
        }
        task.expirationHandler = { work.cancel() }
    }
}
