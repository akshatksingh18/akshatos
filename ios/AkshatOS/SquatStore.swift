import Foundation
import SwiftData
import SwiftUI
import UserNotifications

enum SquatSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedSession.self] }

    @Model final class SavedSession {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ session: SquatSession) throws {
            id = session.id
            payload = try JSONEncoder().encode(session)
        }
    }
}

enum SquatMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SquatSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

final class ReminderService: NSObject, UNUserNotificationCenterDelegate {
    static let regular = "akshatos.squats.regular"
    static let snooze = "akshatos.squats.snooze"
    let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

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

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        completion([.banner, .list, .sound])
    }
}

@MainActor final class SquatStore: ObservableObject {
    @Published private(set) var sessions: [SquatSession] = []
    @Published private(set) var busy = false
    @Published private(set) var operational = "Ready"
    @Published private(set) var nextReminder: Date?
    @Published private(set) var snoozeReminder: Date?
    @Published var message: String?
    @Published var summary: SquatSession?
    @Published var interval: Int { didSet { defaults.set(interval, forKey: "squats.interval") } }
    @Published var goal: Int { didSet { defaults.set(goal, forKey: "squats.goal") } }
    private let defaults: UserDefaults
    private var container: ModelContainer?
    private let reminders = ReminderService()
    var active: SquatSession? { sessions.first { $0.isActive } }
    var today: [SquatSession] { sessions.filter { $0.day == SquatSession.dayKey(Date()) } }
    var todayCount: Int { today.reduce(0) { $0 + $1.count } }
    var todayGoal: Int? {
        if let first = today.sorted(by: { $0.started < $1.started }).first { return first.goal }
        return goal > 0 ? goal : nil
    }
    var staleDay: Bool { active.map { $0.day != SquatSession.dayKey(Date()) } ?? false }
    var streaks: (current: Int, best: Int) { SquatSession.streaks(sessions) }
    var storageAvailable: Bool { container != nil }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        interval = max(1, min(180, defaults.object(forKey: "squats.interval") as? Int ?? 45))
        goal = max(0, min(100, defaults.integer(forKey: "squats.goal")))
        do {
            let schema = Schema(versionedSchema: SquatSchemaV1.self)
            let config = ModelConfiguration("Squats", schema: schema)
            let db = try ModelContainer(for: schema, migrationPlan: SquatMigration.self,
                                        configurations: [config])
            let rows = try db.mainContext.fetch(FetchDescriptor<SquatSchemaV1.SavedSession>())
            let decoded = try rows.map { try JSONDecoder().decode(SquatSession.self, from: $0.payload) }
            guard decoded.filter({ $0.isActive }).count <= 1 else {
                throw CocoaError(.fileReadCorruptFile)
            }
            sessions = decoded.sorted { $0.started > $1.started }
            container = db
        } catch {
            operational = "Storage unavailable"
            message = "Your local data could not be opened. Nothing was erased. Restart the app; if this persists, keep it installed and report the error."
        }
    }

    private func save(_ session: SquatSession) throws {
        guard let context = container?.mainContext else { throw CocoaError(.fileWriteUnknown) }
        do {
            let data = try JSONEncoder().encode(session)
            let rows = try context.fetch(FetchDescriptor<SquatSchemaV1.SavedSession>())
            if let row = rows.first(where: { $0.id == session.id }) { row.payload = data }
            else { context.insert(try SquatSchemaV1.SavedSession(session)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        sessions.removeAll { $0.id == session.id }
        sessions.append(session)
        sessions.sort { $0.started > $1.started }
    }

    func refresh() async {
        guard !busy else { return }
        busy = true
        await reconcile()
        busy = false
    }

    private func reconcile() async {
        guard storageAvailable else { operational = "Storage unavailable"; return }
        let settings = await reminders.center.notificationSettings()
        let requests = await reminders.center.pendingNotificationRequests()
        nextReminder = nil
        snoozeReminder = nil
        guard let session = active else {
            reminders.cancel()
            operational = today.isEmpty ? "Ready" : "Day complete"
            return
        }
        if staleDay {
            reminders.cancel()
            operational = "Finish previous day"
            return
        }
        guard session.state == .running else {
            reminders.cancel()
            operational = "Paused"
            return
        }
        guard ReminderService.allowed(settings.authorizationStatus), settings.alertSetting == .enabled else {
            operational = "Notifications blocked"
            return
        }
        guard let request = requests.first(where: { $0.identifier == ReminderService.regular }),
              request.content.userInfo["session"] as? String == session.id.uuidString,
              let trigger = request.trigger as? UNTimeIntervalNotificationTrigger,
              trigger.repeats, trigger.timeInterval == TimeInterval(session.interval * 60) else {
            operational = "Reminder needs repair"
            return
        }
        nextReminder = trigger.nextTriggerDate()
        let snoozeTrigger = requests.first(where: { $0.identifier == ReminderService.snooze })?.trigger as? UNTimeIntervalNotificationTrigger
        snoozeReminder = snoozeTrigger?.nextTriggerDate()
        operational = "Running"
    }

    private func perform(_ operation: () async throws -> Void) async {
        guard !busy, storageAvailable else { return }
        busy = true
        defer { busy = false }
        do { try await operation() }
        catch { message = "Could not complete that action: \(error.localizedDescription). Your saved history was kept." }
        await reconcile()
    }

    func start() async {
        await perform {
            guard active == nil, (1...180).contains(interval) else { return }
            guard try await reminders.authorize() else {
                message = "Allow notifications in iOS Settings before starting your day."
                return
            }
            let first = today.sorted { $0.started < $1.started }.first
            let snapshot = first != nil ? first!.goal : (goal > 0 ? goal : nil)
            var session = SquatSession(day: SquatSession.dayKey(Date()), started: Date(),
                                       interval: interval, goal: snapshot)
            // Save recoverable intent before scheduling. A failed schedule leaves a paused session.
            try save(session)
            try await reminders.schedule(session)
            session.state = .running
            do { try save(session) } catch { reminders.cancel(); throw error }
        }
    }

    func pause() async {
        await perform {
            guard var session = active, session.state == .running else { return }
            reminders.cancel()
            session.state = .paused
            session.log(SquatEvent(date: Date(), kind: .pause))
            try save(session)
        }
    }

    func resume() async {
        await perform {
            guard var session = active, !staleDay else { return }
            guard try await reminders.authorize() else {
                message = "Notifications are disabled. Enable them in iOS Settings."
                return
            }
            reminders.cancel()
            try await reminders.schedule(session)
            session.state = .running
            session.log(SquatEvent(date: Date(), kind: .resume))
            do { try save(session) } catch { reminders.cancel(); throw error }
        }
    }

    func done() async {
        await perform {
            guard var session = active, !staleDay else { return }
            session.log(SquatEvent(date: Date(), kind: .done))
            try save(session)
        }
    }

    func undo() async {
        await perform {
            guard var session = active, !staleDay else { return }
            session.undo()
            try save(session)
        }
    }

    func snooze() async {
        await perform {
            guard var session = active, !staleDay, operational == "Running" else { return }
            try await reminders.schedule(session, snooze: true)
            session.log(SquatEvent(date: Date(), kind: .snooze))
            do { try save(session) } catch {
                reminders.center.removePendingNotificationRequests(withIdentifiers: [ReminderService.snooze])
                throw error
            }
        }
    }

    func end() async {
        await perform {
            guard var session = active else { return }
            reminders.cancel()
            session.state = .ended
            session.ended = Date()
            try save(session)
            summary = session
        }
    }
}
