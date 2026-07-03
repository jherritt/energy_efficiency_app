import Foundation
import UserNotifications

/// Manages the single, opt-in local notification Amperly is allowed to send:
/// an afternoon nudge when the day's efficiency is trending low.
///
/// Privacy: this helper schedules a *local* notification only. Nothing is sent
/// off the device, no remote push, no analytics. It runs entirely on-device and
/// only when the user has explicitly enabled the nudge in Settings.
@MainActor
final class NotificationManager {

    static let shared = NotificationManager()

    /// Stable identifier so we can replace or cancel the single scheduled nudge.
    private let nudgeIdentifier = "com.amperly.Amperly.lowEfficiencyNudge"

    /// The hour of day (24h) the nudge fires when conditions are met.
    private let nudgeHour = 15
    private let nudgeMinute = 0

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    // MARK: - Authorization

    /// Requests permission to show local notifications. Returns whether the user
    /// granted it. Safe to call repeatedly; the system only prompts once.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Current authorization status, for surfacing state in Settings.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Schedules (or re-schedules) the afternoon low-efficiency nudge.
    ///
    /// Only schedules when `isEnabled` is true and the day is genuinely trending
    /// low: a lot of energy already spent with few points earned. Otherwise it
    /// cancels any pending nudge so the user is never nagged on a good day.
    ///
    /// - Parameters:
    ///   - isEnabled: the persisted opt-in from Settings.
    ///   - efficiency: today's efficiency (0...100), or nil when unauthorized.
    ///   - energySpent: battery-% of energy already spent today.
    ///   - pointsEarned: points earned so far today.
    func refreshLowEfficiencyNudge(isEnabled: Bool,
                                   efficiency: Double?,
                                   energySpent: Double,
                                   pointsEarned: Double) async {
        guard isEnabled else {
            cancelLowEfficiencyNudge()
            return
        }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            cancelLowEfficiencyNudge()
            return
        }

        // "Trending low": meaningful energy already burned but few points to show
        // for it. Thresholds are intentionally conservative so the nudge is rare.
        let burnedALot = energySpent >= 35
        let fewPoints = pointsEarned < 30
        let lowEfficiency = (efficiency ?? 100) < 55
        let trendingLow = burnedALot && (fewPoints || lowEfficiency)

        // Always clear the old request first so we never stack duplicates.
        cancelLowEfficiencyNudge()
        guard trendingLow else { return }

        let now = Date()
        let calendar = Calendar.current
        let afternoon = calendar.date(bySettingHour: nudgeHour, minute: nudgeMinute, second: 0, of: now) ?? now
        let evening = calendar.date(bySettingHour: quietHour, minute: 0, second: 0, of: now) ?? now

        let content = UNMutableNotificationContent()
        content.title = "Low energy efficiency"
        content.body = "You have burned a lot of energy with few points so far. A short walk or some water can turn the day around."
        content.sound = .default

        // Before the afternoon slot: schedule for 3pm today. Already past it but
        // before quiet hours: nudge shortly (the old code silently gave up here,
        // which is why nudges never seemed to fire). In quiet hours: skip.
        let trigger: UNNotificationTrigger
        if now < afternoon {
            var comps = DateComponents()
            comps.hour = nudgeHour
            comps.minute = nudgeMinute
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        } else if now < evening {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 120, repeats: false)
        } else {
            return
        }

        let request = UNNotificationRequest(identifier: nudgeIdentifier, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            // Silent failure is acceptable for a best-effort local nudge; we never
            // surface scheduling errors to the user for a non-critical reminder.
        }
    }

    /// No nudges at or after this hour (avoid pinging near bedtime).
    private var quietHour: Int { 21 }

    /// True when the user has explicitly DENIED notifications at the system
    /// level, so Settings can surface why the nudge cannot fire.
    func isDenied() async -> Bool {
        await authorizationStatus() == .denied
    }

    /// Cancels any pending low-efficiency nudge. Called when the user turns the
    /// opt-in off, or when the day is no longer trending low.
    func cancelLowEfficiencyNudge() {
        center.removePendingNotificationRequests(withIdentifiers: [nudgeIdentifier])
    }
}
