import Foundation
import UserNotifications

/// The weekly "time to measure" notification. Only ever touches its own identifier, so it cannot
/// disturb Pushup Reminder's schedule. The app layer routes a tapped reminder here by namespace.
@MainActor protocol BodyReminding {
    func enable(weekday: Int, hour: Int, minute: Int) async throws -> Bool
    func disable()
}

struct BodyReminderService: BodyReminding {
    static let namespace = "akshatos.body."
    static let weekly = namespace + "weekly"
    static let title = "Body measurements"
    static let body = "Time for this week's measurements."

    /// Returns false when notifications are not allowed, so the caller can say so instead of
    /// showing a reminder that will never arrive.
    func enable(weekday: Int, hour: Int, minute: Int) async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        if await center.notificationSettings().authorizationStatus == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        }
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return false }
        center.removePendingNotificationRequests(withIdentifiers: [Self.weekly])
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(hour: hour, minute: minute, weekday: weekday), repeats: true)
        try await center.add(UNNotificationRequest(identifier: Self.weekly, content: content, trigger: trigger))
        return true
    }

    func disable() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.weekly])
    }
}
