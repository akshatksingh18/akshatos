import UserNotifications

/// Sole owner of the process-wide delegate. Feature schedulers never replace it.
@MainActor final class AppNotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    private let squats: SquatStore

    init(squats: SquatStore) {
        self.squats = squats
        super.init()
        UNUserNotificationCenter.current().delegate = self
        // This is the hub's complete category registry; add future feature categories here.
        UNUserNotificationCenter.current().setNotificationCategories([ReminderService.category()])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completion: @escaping () -> Void) {
        Task { @MainActor in
            defer { completion() }
            let notification = response.notification
            if let action = Self.action(request: notification.request, delivered: notification.date,
                                        identifier: response.actionIdentifier) {
                // receive persists to the inbox before any asynchronous service work or busy check.
                await squats.receive(action)
            }
        }
    }

    static func action(request: UNNotificationRequest, delivered: Date, identifier: String,
                       now: Date = Date()) -> SquatAction? {
        guard [ReminderService.regular, ReminderService.snooze].contains(request.identifier),
              request.content.categoryIdentifier == ReminderService.categoryID,
              let rawSession = request.content.userInfo["session"] as? String,
              let session = UUID(uuidString: rawSession) else { return nil }
        let kind: SquatAction.Kind
        switch identifier {
        case ReminderService.doneAction: kind = .done
        case ReminderService.pauseAction: kind = .pause
        case ReminderService.snoozeAction: kind = .snooze
        default: return nil // Opening/dismissing a notification is never a completed set.
        }
        return SquatAction(id: SquatAction.notificationID(session: session, request: request.identifier,
            delivered: delivered, action: identifier), sessionID: session, kind: kind,
            date: now, day: SquatSession.dayKey(now), source: "notification")
    }
}
