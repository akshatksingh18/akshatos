import Foundation
import UserNotifications

struct ReminderSnapshot {
    var allowed: Bool
    var authorization: NotificationAuthorization = .notDetermined
    var sessionID: UUID?
    var interval: TimeInterval?
    var actionable: Bool = true
    var next: Date?
    var snooze: Date?
}

@MainActor protocol SquatReminders {
    func authorize() async throws -> Bool
    func snapshot() async -> ReminderSnapshot
    func schedule(_ session: SquatSession, snoozeUntil: Date?) async throws
    func cancel()
    func cancelSnooze()
}

@MainActor final class ReminderService: SquatReminders {
    static let regular = "akshatos.squats.regular"
    static let snooze = "akshatos.squats.snooze"
    static let categoryID = "akshatos.squats.reminder"
    static let doneAction = "akshatos.squats.done"
    static let pauseAction = "akshatos.squats.pause"
    static let snoozeAction = "akshatos.squats.snooze-ten"
    let center = UNUserNotificationCenter.current()

    static func category() -> UNNotificationCategory {
        UNNotificationCategory(identifier: categoryID, actions: [
            UNNotificationAction(identifier: doneAction, title: "Done", options: []),
            UNNotificationAction(identifier: pauseAction, title: "Pause", options: []),
            UNNotificationAction(identifier: snoozeAction, title: "Remind me in 10 min", options: [])
        ], intentIdentifiers: [], options: [])
    }

    func authorize() async throws -> Bool {
        let before = await center.notificationSettings()
        if before.authorizationStatus == .notDetermined {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        }
        let settings = await center.notificationSettings()
        return Self.allowed(settings.authorizationStatus) && settings.alertSetting == .enabled
    }

    static func allowed(_ status: UNAuthorizationStatus) -> Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    static func authorization(_ status: UNAuthorizationStatus) -> NotificationAuthorization {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .provisional: return .provisional
        case .ephemeral: return .ephemeral
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func snapshot() async -> ReminderSnapshot {
        let settings = await center.notificationSettings()
        let requests = await center.pendingNotificationRequests()
        let regular = requests.first { $0.identifier == Self.regular }
        let trigger = regular?.trigger as? UNTimeIntervalNotificationTrigger
        let sessionID = (regular?.content.userInfo["session"] as? String).flatMap(UUID.init(uuidString:))
        let snooze = requests.first { $0.identifier == Self.snooze &&
            $0.content.userInfo["session"] as? String == sessionID?.uuidString }
        return ReminderSnapshot(allowed: Self.allowed(settings.authorizationStatus) && settings.alertSetting == .enabled,
            authorization: Self.authorization(settings.authorizationStatus),
            sessionID: sessionID, interval: trigger?.repeats == true ? trigger?.timeInterval : nil,
            actionable: regular?.content.categoryIdentifier == Self.categoryID,
            next: trigger?.nextTriggerDate(), snooze: (snooze?.trigger as? UNTimeIntervalNotificationTrigger)?.nextTriggerDate())
    }

    func schedule(_ session: SquatSession, snoozeUntil: Date? = nil) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Time for a squat break"
        content.body = "Take a movement break, then tap Done to log your set."
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = ["session": session.id.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: snoozeUntil.map { max(1, $0.timeIntervalSinceNow) } ?? TimeInterval(session.interval * 60),
            repeats: snoozeUntil == nil)
        try await center.add(UNNotificationRequest(identifier: snoozeUntil == nil ? Self.regular : Self.snooze,
            content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.regular, Self.snooze])
        center.removeDeliveredNotifications(withIdentifiers: [Self.regular, Self.snooze])
    }

    func cancelSnooze() { center.removePendingNotificationRequests(withIdentifiers: [Self.snooze]) }
}
