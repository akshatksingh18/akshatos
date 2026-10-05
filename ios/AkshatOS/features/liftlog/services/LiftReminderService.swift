import Foundation
import UserNotifications

/// The "still working out?" notification sent after an hour with nothing logged. Only ever touches
/// its own identifier, so it cannot disturb Pushup Reminder or Body. The app layer routes a tapped
/// reminder here by namespace and hands its Finish action to the store.
@MainActor protocol LiftReminding {
    /// Replaces any pending reminder with one at `date`. `canFinish` adds the Finish action, which
    /// only makes sense once a set has been logged.
    func schedule(at date: Date, workoutID: UUID, canFinish: Bool) async
    func cancel()
}

struct LiftReminderService: LiftReminding {
    static let namespace = "akshatos.liftlog."
    static let inactive = namespace + "inactive"
    static let categoryID = namespace + "inactive.category"
    static let finishAction = namespace + "finish"
    static let title = "Still working out?"
    static let body = "Nothing logged in Lift Log for an hour. Finish the workout if you are done."

    static func category() -> UNNotificationCategory {
        UNNotificationCategory(identifier: categoryID,
                               actions: [UNNotificationAction(identifier: finishAction,
                                                              title: "Finish workout", options: [])],
                               intentIdentifiers: [])
    }

    /// The workout a reminder was sent for, so a late answer cannot finish a newer workout.
    static func workoutID(of request: UNNotificationRequest) -> UUID? {
        guard request.identifier == inactive else { return nil }
        return (request.content.userInfo["workout"] as? String).flatMap(UUID.init(uuidString:))
    }

    /// Never asks for permission: the prompt would interrupt starting a workout. Notifications are
    /// already allowed for the hub's other reminders; without that, nothing is scheduled.
    func schedule(at date: Date, workoutID: UUID, canFinish: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.inactive])
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }
        let content = UNMutableNotificationContent()
        content.title = Self.title
        content.body = Self.body
        content.sound = .default
        content.userInfo = ["workout": workoutID.uuidString]
        if canFinish { content.categoryIdentifier = Self.categoryID }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow),
                                                        repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.inactive, content: content,
                                                    trigger: trigger))
    }

    func cancel() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.inactive])
        center.removeDeliveredNotifications(withIdentifiers: [Self.inactive])
    }
}
