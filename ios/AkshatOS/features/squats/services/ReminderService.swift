import Foundation
import UserNotifications

final class ReminderService {
    static let regular = "akshatos.squats.regular"
    static let snooze = "akshatos.squats.snooze"
    let center = UNUserNotificationCenter.current()

    func authorize() async throws -> Bool {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            return try await center.requestAuthorization(options: [.alert, .sound])
        }
        return Self.allowed(settings.authorizationStatus)
    }

    static func allowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    func schedule(_ session: SquatSession, snooze: Bool = false) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time for a squat break"
        content.body = "A little movement goes a long way. Open AkshatOS and log your set."
        content.sound = .default
        content.userInfo = ["session": session.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: snooze ? 600 : TimeInterval(session.interval * 60), repeats: !snooze)
        try await center.add(UNNotificationRequest(identifier: snooze ? Self.snooze : Self.regular,
                                                  content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.regular, Self.snooze])
        center.removeDeliveredNotifications(withIdentifiers: [Self.regular, Self.snooze])
    }

}
