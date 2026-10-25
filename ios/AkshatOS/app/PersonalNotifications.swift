import Foundation
import UserNotifications

@MainActor final class PersonalPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var stillStudying: Bool { didSet { defaults.set(stillStudying, forKey: "personal.study-check") } }
    @Published var checkMinutes: Int { didSet { defaults.set(checkMinutes, forKey: "personal.check-minutes") } }
    @Published var breakReminder: Bool { didSet { defaults.set(breakReminder, forKey: "personal.break-reminder") } }
    @Published var breakMinutes: Int { didSet { defaults.set(breakMinutes, forKey: "personal.break-minutes") } }
    @Published var morningPlan: Bool { didSet { defaults.set(morningPlan, forKey: "personal.morning-plan") } }
    @Published var morningHour: Int { didSet { defaults.set(morningHour, forKey: "personal.morning-hour") } }
    @Published var journalReminder: Bool { didSet { defaults.set(journalReminder, forKey: "personal.journal-reminder") } }
    @Published var journalHour: Int { didSet { defaults.set(journalHour, forKey: "personal.journal-hour") } }
    @Published var badge: Bool { didSet { defaults.set(badge, forKey: "personal.badge") } }
    @Published var fullDayChallenge: Bool { didSet {
        defaults.set(fullDayChallenge, forKey: "personal.full-day-challenge")
        if fullDayChallenge && fullDayStart.isEmpty { fullDayStart = ActivityDayClock().key(Date()) }
    } }
    @Published var fullDayStart: String { didSet { defaults.set(fullDayStart, forKey: "personal.full-day-start") } }
    @Published var seenMilestone: Int { didSet { defaults.set(seenMilestone, forKey: "personal.seen-milestone") } }
    @Published var lastStudyConfirmation: Date? { didSet { defaults.set(lastStudyConfirmation, forKey: "personal.study-confirmation") } }
    @Published var challengeDay: String { didSet { defaults.set(challengeDay, forKey: "personal.challenge-day") } }
    @Published var challengeAccepted: Bool { didSet { defaults.set(challengeAccepted, forKey: "personal.challenge-accepted") } }
    @Published var challengeStartedAt: Date? { didSet { defaults.set(challengeStartedAt, forKey: "personal.challenge-started") } }
    @Published var fitnessStopped: Bool { didSet { defaults.set(fitnessStopped, forKey: "personal.fitness-stopped") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        stillStudying = defaults.bool(forKey: "personal.study-check")
        checkMinutes = defaults.object(forKey: "personal.check-minutes") as? Int ?? 30
        breakReminder = defaults.bool(forKey: "personal.break-reminder")
        breakMinutes = defaults.object(forKey: "personal.break-minutes") as? Int ?? 15
        morningPlan = defaults.bool(forKey: "personal.morning-plan")
        morningHour = defaults.object(forKey: "personal.morning-hour") as? Int ?? 9
        // Retired features retain their archive keys, but cannot reactivate after upgrade/restore.
        journalReminder = false
        defaults.set(false, forKey: "personal.journal-reminder")
        journalHour = defaults.object(forKey: "personal.journal-hour") as? Int ?? 22
        badge = defaults.bool(forKey: "personal.badge")
        fullDayStart = defaults.string(forKey: "personal.full-day-start") ?? ""
        seenMilestone = defaults.integer(forKey: "personal.seen-milestone")
        fullDayChallenge = false
        defaults.set(false, forKey: "personal.full-day-challenge")
        lastStudyConfirmation = defaults.object(forKey: "personal.study-confirmation") as? Date
        challengeDay = defaults.string(forKey: "personal.challenge-day") ?? ""
        challengeAccepted = defaults.bool(forKey: "personal.challenge-accepted")
        challengeStartedAt = defaults.object(forKey: "personal.challenge-started") as? Date
        fitnessStopped = defaults.bool(forKey: "personal.fitness-stopped")
    }
}

/// Serial, bounded scheduling. Only this namespace is reconciled; legacy/other feature requests survive.
@MainActor final class PersonalNotifications: ObservableObject {
    static let namespace = "akshatos.personal."
    static let categoryID = namespace + "study"
    static let pauseAction = namespace + "pause"
    static let keepGoingAction = namespace + "keep-going"
    @Published private(set) var status = "Reminders are optional."
    private let center: any PersonalNotificationCenter
    private let study: StudyLogStore
    private let todo: TodoStore
    private let preferences: PersonalPreferences
    private var task: Task<Void, Never>?
    private var dirty = false
    init(study: StudyLogStore, todo: TodoStore, preferences: PersonalPreferences,
         center: (any PersonalNotificationCenter)? = nil) {
        self.study = study; self.todo = todo; self.preferences = preferences; self.center = center ?? SystemPersonalNotificationCenter()
    }
    static func category() -> UNNotificationCategory {
        UNNotificationCategory(identifier: categoryID, actions: [
            UNNotificationAction(identifier: keepGoingAction, title: "Keep going", options: [.foreground]),
            UNNotificationAction(identifier: pauseAction, title: "Pause study", options: [.foreground])
        ], intentIdentifiers: [])
    }
    func requestPermission() async {
        do {
            let allowed = try await center.authorize()
            status = allowed ? "Notifications allowed." : "Notifications are off. Enable them in iPhone Settings."
        } catch { status = "Notification permission could not be checked. Try again." }
        reconcile()
    }
    func reconcile() {
        dirty = true
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            while dirty { dirty = false; await update() }
            task = nil
        }
    }
    func waitUntilSettled() async { await task?.value }
    private func update() async {
        let authorization = await center.authorization()
        let pending = await center.pending()
        let owned = pending.filter { $0.identifier.hasPrefix(Self.namespace) }
        let otherCount = pending.count - owned.count
        // Retire old invitations even when permission or another local store is unavailable.
        center.remove(owned.filter { $0.identifier == Self.namespace + "journal" }.map(\.identifier))
        center.removeDelivered([Self.namespace + "journal"])
        guard authorization == .authorized || authorization == .provisional else {
            status = "Notifications are off. Local study and lists still work."
            if preferences.badge { try? await center.badge(0) }
            return
        }
        // A failed store read must not cancel the last known good intentions for that feature.
        guard study.storageAvailable, todo.available else { status = "Reminder update waiting for local data."; return }
        var desired: [UNNotificationRequest] = []
        let now = Date()
        for item in todo.visible.filter({ $0.completedAt == nil && $0.hasTime && ($0.due ?? .distantPast) > now })
            .sorted(by: { $0.due! < $1.due! }).prefix(15) {
            let content = UNMutableNotificationContent(); content.title = "Task reminder"; content.body = item.title; content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.due!), repeats: false)
            desired.append(UNNotificationRequest(identifier: Self.namespace + "todo." + item.id.uuidString, content: content, trigger: trigger))
        }
        if preferences.stillStudying, let running = study.log.running {
            let content = UNMutableNotificationContent(); content.title = "Still studying?"
            content.body = "Keep going, or pause and correct the block if you stopped earlier."
            content.sound = .default; content.categoryIdentifier = Self.categoryID
            let anchor = max(running.start, preferences.lastStudyConfirmation ?? running.start)
            content.userInfo = ["anchor": anchor.timeIntervalSince1970, "blockID": running.id.uuidString]
            desired.append(UNNotificationRequest(identifier: Self.namespace + "study", content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(min(120, max(5, preferences.checkMinutes))) * 60, repeats: true)))
        }
        if preferences.breakReminder, !study.isRunning, study.studiedToday(at: now) > 0,
           study.studiedToday(at: now) < Double(study.targetToday(at: now)), let end = study.lastPause {
            let date = end.addingTimeInterval(Double(min(180, max(5, preferences.breakMinutes))) * 60)
            if date > now {
                let content = UNMutableNotificationContent(); content.title = "Back to it?"; content.body = "Your study timer is paused."; content.sound = .default
                desired.append(UNNotificationRequest(identifier: Self.namespace + "break", content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date), repeats: false)))
            }
        }
        if preferences.morningPlan {
            // One upcoming eligible invitation, replenished on app activity. Starting study cancels
            // today's invitation; a closed app is never assumed to inspect its records at delivery.
            for offset in 0..<8 {
                guard let day = Calendar.current.date(byAdding: .day, value: offset, to: now),
                      let date = Calendar.current.date(bySettingHour: min(23, max(0, preferences.morningHour)), minute: 0, second: 0, of: day), date > now else { continue }
                let key = study.clock.key(for: date)
                let started = study.log.segments.contains { segment in
                    study.clock.pieces(of: segment, now: now).contains { $0.day == key } || study.clock.key(for: segment.start) == key
                }
                if started { continue }
                let content = UNMutableNotificationContent(); content.title = "A little plan for today"
                content.body = "Choose your priorities and check your study aim."; content.sound = .default
                desired.append(UNNotificationRequest(identifier: Self.namespace + "morning", content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)))
                break
            }
        }
        let capacity = max(0, 64 - otherCount - 2)
        if study.isRunning {
            desired = desired.map { request in
                // Keep timed tasks and invitations in Notification Center without interrupting a block,
                // even if AkshatOS is allowed through DND. The explicit study-check opt-in is separate.
                guard request.identifier != Self.namespace + "study",
                      let content = request.content.mutableCopy() as? UNMutableNotificationContent else { return request }
                content.sound = nil; content.interruptionLevel = .passive
                return UNNotificationRequest(identifier: request.identifier, content: content, trigger: request.trigger)
            }
        }
        let planned = Array(desired.prefix(capacity)), IDs = Set(planned.map(\.identifier))
        // Remove only surplus own requests; unrelated modules are never cancelled to create room.
        center.remove( owned.filter { !IDs.contains($0.identifier) }.map(\.identifier))
        do {
            for request in planned {
                if let previous = owned.first(where: { $0.identifier == request.identifier }),
                   previous.content == request.content, previous.trigger == request.trigger { continue }
                try await center.add(request)
            }
            let plan = todo.plan(todo.today)
            let left = preferences.badge ? max(0, (plan?.selected.count ?? 0) - (plan?.completed.count ?? 0)) : 0
            try await center.badge(left)
            let dueCount = desired.filter { $0.identifier.contains(".todo.") }.count
            status = "\(planned.count) scheduled. Timed tasks: next \(min(dueCount, capacity)) of at most 15; opening the app refreshes the window."
            if study.isRunning { status += " Tasks and invitations stay quiet while studying." }
            if planned.count < desired.count { status += " Other reminders currently use the remaining capacity." }
        } catch { status = "Some reminders could not be scheduled. Open Settings and retry. Existing unrelated reminders are unchanged." }
    }
    func respond(_ identifier: String, blockID: UUID?) {
        study.load()
        guard let blockID, study.log.running?.id == blockID else { reconcile(); return }
        if identifier == Self.pauseAction { study.pause() }
        if identifier == Self.keepGoingAction { preferences.lastStudyConfirmation = Date() }
        reconcile()
    }
}
