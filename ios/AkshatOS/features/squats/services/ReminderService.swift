import Foundation
import UserNotifications

struct ReminderSnapshot {
    var allowed: Bool
    var authorization: NotificationAuthorization = .notDetermined
    var sessionID: UUID?
    var interval: TimeInterval?
    var actionable: Bool = true
    var activeRequestCount = 0
    var next: Date?
    var hasLegacySnooze = false
    var dailyStartScheduled = false
}

@MainActor protocol SquatReminders {
    func authorize() async throws -> Bool
    func snapshot() async -> ReminderSnapshot
    func schedule(_ session: SquatSession, firstReminderAt: Date) async throws
    func ensureDailyStartReminder() async throws
    func cancel()
    func cancelDailyStartReminder()
}

@MainActor final class ReminderService: SquatReminders {
    /// Every Squats notification identifier begins with this, which is how the app layer tells a
    /// tapped Squats notification from another feature's and opens the right one.
    ///
    /// The identifiers below are composed from it rather than written out, so the namespace is
    /// provably their prefix. Their resulting strings are unchanged: a different value would orphan
    /// the requests already pending on the phone.
    static let namespace = "akshatos.squats."
    static let regular = namespace + "regular"
    static let automaticPrefix = namespace + "automatic-nudge."
    static let dailyStart = namespace + "daily-start"
    static let legacySnooze = namespace + "snooze"
    static let categoryID = namespace + "reminder"
    static let doneAction = namespace + "done"
    static let pauseAction = namespace + "pause"
    static let legacySnoozeAction = namespace + "snooze-ten"
    static let automaticNudgeInterval: TimeInterval = 600
    static let automaticNudgeCount = 59
    static let scheduleVersion = 2
    let center = UNUserNotificationCenter.current()

    static var activeIdentifiers: [String] {
        [regular, legacySnooze] + (0..<automaticNudgeCount).map { automaticPrefix + String($0) }
    }

    static func isActiveIdentifier(_ identifier: String) -> Bool {
        identifier == regular || identifier == legacySnooze || identifier.hasPrefix(automaticPrefix)
    }

    static func category() -> UNNotificationCategory {
        UNNotificationCategory(identifier: categoryID, actions: [
            UNNotificationAction(identifier: doneAction, title: "Done", options: []),
            UNNotificationAction(identifier: pauseAction, title: "Pause", options: [])
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
        let active = requests.filter { Self.isActiveIdentifier($0.identifier) }
        let current = active.filter { $0.identifier != Self.legacySnooze }
        let dated = current.compactMap { request -> (UNNotificationRequest, Date)? in
            guard let trigger = request.trigger as? UNTimeIntervalNotificationTrigger,
                  let date = trigger.nextTriggerDate() else { return nil }
            return (request, date)
        }.sorted { $0.1 < $1.1 }
        let sessionIDs = Set(current.compactMap {
            ($0.content.userInfo["session"] as? String).flatMap(UUID.init(uuidString:))
        })
        let intervals = Set(current.compactMap { contentInterval($0.content) })
        let actionable = !current.isEmpty && current.allSatisfy {
            $0.content.categoryIdentifier == Self.categoryID &&
            ($0.content.userInfo["scheduleVersion"] as? Int) == Self.scheduleVersion
        }
        return ReminderSnapshot(
            allowed: Self.allowed(settings.authorizationStatus) && settings.alertSetting == .enabled,
            authorization: Self.authorization(settings.authorizationStatus),
            sessionID: sessionIDs.count == 1 ? sessionIDs.first : nil,
            interval: intervals.count == 1 ? intervals.first : nil,
            actionable: actionable,
            activeRequestCount: dated.count,
            next: dated.first?.1,
            hasLegacySnooze: active.contains { $0.identifier == Self.legacySnooze },
            dailyStartScheduled: requests.contains { $0.identifier == Self.dailyStart })
    }

    func schedule(_ session: SquatSession, firstReminderAt: Date) async throws {
        cancel()
        let now = Date()
        let interval = TimeInterval(session.interval * 60)
        var requests: [(String, Date, Bool)] = []
        if firstReminderAt > now { requests.append((Self.regular, firstReminderAt, false)) }
        let nextNudge: Date
        if firstReminderAt > now {
            nextNudge = firstReminderAt.addingTimeInterval(Self.automaticNudgeInterval)
        } else {
            let elapsed = max(0, now.timeIntervalSince(firstReminderAt))
            nextNudge = firstReminderAt.addingTimeInterval(
                (floor(elapsed / Self.automaticNudgeInterval) + 1) * Self.automaticNudgeInterval)
        }
        for index in 0..<Self.automaticNudgeCount {
            requests.append((Self.automaticPrefix + String(index),
                             nextNudge.addingTimeInterval(TimeInterval(index) * Self.automaticNudgeInterval), true))
        }
        do {
            for request in requests {
                let content = reminderContent(session: session, interval: interval, automatic: request.2)
                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(1, request.1.timeIntervalSinceNow), repeats: false)
                try await center.add(UNNotificationRequest(identifier: request.0, content: content, trigger: trigger))
            }
        } catch {
            cancel()
            throw error
        }
    }

    func ensureDailyStartReminder() async throws {
        let requests = await center.pendingNotificationRequests()
        guard !requests.contains(where: { $0.identifier == Self.dailyStart }) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Start your Squats day"
        content.body = "Open AkshatOS to start today's movement reminders."
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: 9, minute: 0), repeats: true)
        try await center.add(UNNotificationRequest(identifier: Self.dailyStart, content: content, trigger: trigger))
    }

    func cancel() {
        center.removePendingNotificationRequests(withIdentifiers: Self.activeIdentifiers)
        center.removeDeliveredNotifications(withIdentifiers: Self.activeIdentifiers)
    }

    func cancelDailyStartReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.dailyStart])
        center.removeDeliveredNotifications(withIdentifiers: [Self.dailyStart])
    }

    private func reminderContent(session: SquatSession, interval: TimeInterval,
                                 automatic: Bool) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = automatic ? "Still time for a squat break" : "Time for a squat break"
        content.body = automatic
            ? "When you finish a set, tap Done to return to your normal interval."
            : "Take a movement break, then tap Done to log your set."
        content.sound = .default
        content.categoryIdentifier = Self.categoryID
        content.userInfo = [
            "session": session.id.uuidString,
            "interval": Int(interval / 60),
            "scheduleVersion": Self.scheduleVersion
        ]
        return content
    }

    private func contentInterval(_ content: UNNotificationContent) -> TimeInterval? {
        if let value = content.userInfo["interval"] as? Int { return TimeInterval(value * 60) }
        if let value = content.userInfo["interval"] as? NSNumber { return value.doubleValue * 60 }
        return nil
    }
}
