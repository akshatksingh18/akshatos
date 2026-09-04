import XCTest
import SwiftData
import UserNotifications
@testable import AkshatOS

@MainActor private final class MemoryRepository: SquatRepository {
    var values: [SquatSession] = []
    var unavailable = false
    var failSave = false
    func load() throws -> [SquatSession] {
        if unavailable { throw CocoaError(.fileReadNoPermission) }
        return values
    }
    func save(_ session: SquatSession) throws {
        if failSave || unavailable { throw CocoaError(.fileWriteNoPermission) }
        values.removeAll { $0.id == session.id }
        values.append(session)
    }
}

@MainActor private final class MemoryInbox: SquatActionInbox {
    var values: [SquatAction] = []
    var failEnqueue = false
    var failRemove = false
    func pending() throws -> [SquatAction] { values }
    func enqueue(_ action: SquatAction) throws {
        if failEnqueue { throw CocoaError(.fileWriteOutOfSpace) }
        if !values.contains(where: { $0.id == action.id }) { values.append(action) }
    }
    func remove(_ id: String) throws {
        if failRemove { throw CocoaError(.fileWriteOutOfSpace) }
        values.removeAll { $0.id == id }
    }
}

@MainActor private final class FakeReminders: SquatReminders {
    var state = ReminderSnapshot(allowed: true)
    var scheduleCount = 0
    var failSchedule = false
    var duringSchedule: (() async -> Void)?
    var duringSnapshot: (() async -> Void)?
    func authorize() async throws -> Bool { state.allowed }
    func snapshot() async -> ReminderSnapshot {
        if let callback = duringSnapshot {
            duringSnapshot = nil
            await callback()
        }
        return state
    }
    func schedule(_ session: SquatSession, snoozeUntil: Date?) async throws {
        if let callback = duringSchedule {
            duringSchedule = nil
            await callback()
        }
        if failSchedule { throw CocoaError(.fileWriteUnknown) }
        scheduleCount += 1
        if let date = snoozeUntil { state.snooze = date }
        else {
            state.sessionID = session.id
            state.interval = TimeInterval(session.interval * 60)
            state.actionable = true
            state.next = Date().addingTimeInterval(TimeInterval(session.interval * 60))
        }
    }
    func cancel() {
        state.sessionID = nil; state.interval = nil; state.next = nil; state.snooze = nil
    }
    func cancelSnooze() { state.snooze = nil }
}

@MainActor final class SquatsActionTests: XCTestCase {
    private var time: Date { Date(timeIntervalSince1970: 1_788_537_600) }
    private func session() -> SquatSession {
        SquatSession(day: SquatSession.dayKey(time), started: time.addingTimeInterval(-3600),
                     interval: 45, goal: nil, state: .running)
    }
    private func action(_ session: SquatSession, _ kind: SquatAction.Kind = .done,
                        id: String = UUID().uuidString) -> SquatAction {
        SquatAction(id: id, sessionID: session.id, kind: kind, date: time,
                    day: session.day, source: "notification")
    }
    private func make(_ repository: MemoryRepository, _ reminders: FakeReminders,
                      _ inbox: any SquatActionInbox) -> SquatStore {
        let clock = time
        let defaults = UserDefaults(suiteName: "SquatsActionTests.\(UUID().uuidString)")!
        return SquatStore(defaults: defaults, repository: repository, reminders: reminders,
                          inbox: inbox, now: { clock })
    }
    private func fixture() -> (MemoryRepository, FakeReminders, MemoryInbox, SquatStore) {
        let repository = MemoryRepository()
        repository.values = [session()]
        let reminders = FakeReminders()
        reminders.state.sessionID = repository.values[0].id
        reminders.state.interval = 2700
        let inbox = MemoryInbox()
        return (repository, reminders, inbox, make(repository, reminders, inbox))
    }

    func testDuplicateDoneAndUndoSurviveStoreRestart() async throws {
        let (repository, reminders, inbox, store) = fixture()
        let command = action(repository.values[0])
        await store.receive(command)
        await store.receive(command)
        XCTAssertEqual(store.todayCount, 1)
        XCTAssertEqual(reminders.scheduleCount, 0, "Done must not move the cadence")
        await store.undo()
        let reopened = make(repository, reminders, inbox)
        await reopened.receive(command)
        XCTAssertEqual(reopened.todayCount, 0)
        XCTAssertTrue(inbox.values.isEmpty)
    }

    func testSaveFailureKeepsInboxUntilRecovery() async {
        let (repository, _, inbox, store) = fixture()
        repository.failSave = true
        await store.receive(action(repository.values[0]))
        XCTAssertEqual(store.todayCount, 0)
        XCTAssertEqual(inbox.values.count, 1)
        repository.failSave = false
        await store.refresh()
        XCTAssertEqual(store.todayCount, 1)
        XCTAssertEqual(store.pendingActionCount, 0)
    }

    func testCrashAfterSessionCommitBeforeInboxRemovalDoesNotDuplicate() async {
        let (repository, reminders, inbox, store) = fixture()
        inbox.failRemove = true
        await store.receive(action(repository.values[0]))
        XCTAssertEqual(store.todayCount, 1)
        XCTAssertEqual(inbox.values.count, 1)
        inbox.failRemove = false
        let reopened = make(repository, reminders, inbox)
        await reopened.refresh()
        XCTAssertEqual(reopened.todayCount, 1)
        XCTAssertTrue(inbox.values.isEmpty)
    }

    func testProtectedStoreQueuesAndRetriesWithoutLosingDone() async {
        let (repository, reminders, inbox, _) = fixture()
        repository.unavailable = true
        let store = make(repository, reminders, inbox)
        await store.receive(action(repository.values[0]))
        XCTAssertFalse(store.storageAvailable)
        XCTAssertEqual(inbox.values.count, 1)
        repository.unavailable = false
        await store.refresh()
        XCTAssertTrue(store.storageAvailable)
        XCTAssertEqual(store.todayCount, 1)
    }

    func testProtectedPauseCancelsOnlyMatchingSessionAndLaterPersists() async {
        let (repository, reminders, inbox, _) = fixture()
        let active = repository.values[0]
        repository.unavailable = true
        let store = make(repository, reminders, inbox)
        await store.receive(action(active, .pause))
        XCTAssertNil(reminders.state.sessionID)
        repository.unavailable = false
        await store.refresh()
        XCTAssertEqual(store.active?.state, .paused)
        XCTAssertEqual(store.active?.pauseReason, "notification")
    }

    func testForeignProtectedPauseDoesNotCancelCurrentSchedule() async {
        let (repository, reminders, inbox, _) = fixture()
        repository.unavailable = true
        let store = make(repository, reminders, inbox)
        await store.receive(action(session(), .pause))
        XCTAssertEqual(reminders.state.sessionID, repository.values[0].id)
    }

    func testQueuedPauseCancelsEvenWhenEarlierDoneCannotSave() async throws {
        let (repository, reminders, inbox, store) = fixture()
        let active = repository.values[0]
        repository.failSave = true
        try inbox.enqueue(action(active))
        try inbox.enqueue(action(active, .pause))
        await store.refresh()
        XCTAssertNil(reminders.state.sessionID)
        XCTAssertEqual(inbox.values.count, 2)
        repository.failSave = false
        await store.refresh()
        XCTAssertEqual(store.todayCount, 1)
        XCTAssertEqual(store.active?.state, .paused)
        XCTAssertTrue(inbox.values.isEmpty)
    }

    func testSnoozeQueuedBeforeMidnightCannotScheduleForPreviousDay() async {
        let repository = MemoryRepository()
        let midnight = Calendar.current.startOfDay(for: time)
        let tap = midnight.addingTimeInterval(-60)
        let active = SquatSession(day: SquatSession.dayKey(tap), started: tap.addingTimeInterval(-3600),
                                  interval: 45, goal: nil, state: .running)
        repository.values = [active]
        let reminders = FakeReminders()
        reminders.state.sessionID = active.id
        reminders.state.interval = 2700
        let inbox = MemoryInbox()
        let store = SquatStore(repository: repository, reminders: reminders, inbox: inbox,
                               now: { midnight.addingTimeInterval(60) })
        let command = SquatAction(id: UUID().uuidString, sessionID: active.id, kind: .snooze,
                                  date: tap, day: active.day, source: "notification")
        await store.receive(command)
        XCTAssertEqual(reminders.scheduleCount, 0)
        XCTAssertNil(reminders.state.snooze)
        XCTAssertEqual(store.operational, "Finish previous day")
    }

    func testSnoozeReplacementPreservesCadenceAndPauseCancelsBoth() async {
        let (repository, reminders, _, store) = fixture()
        let active = repository.values[0]
        let regular = reminders.state.sessionID
        await store.receive(action(active, .snooze))
        await store.receive(action(active, .snooze))
        XCTAssertEqual(reminders.state.sessionID, regular)
        XCTAssertEqual(reminders.state.snooze, time.addingTimeInterval(600))
        XCTAssertEqual(store.todayCount, 0)
        await store.receive(action(active, .pause))
        XCTAssertNil(reminders.state.sessionID)
        XCTAssertNil(reminders.state.snooze)
    }

    func testFailedSnoozeSaveCancelsOneOffAndRetainsCommand() async {
        let (repository, reminders, inbox, store) = fixture()
        repository.failSave = true
        await store.receive(action(repository.values[0], .snooze))
        XCTAssertNil(reminders.state.snooze)
        XCTAssertNotNil(reminders.state.sessionID)
        XCTAssertEqual(inbox.values.count, 1)
        repository.failSave = false
        await store.refresh()
        XCTAssertNotNil(reminders.state.snooze)
        XCTAssertEqual(store.active?.events.filter { $0.kind == .snooze }.count, 1)
    }

    func testSchedulingFailureRetainsSnoozeForRetry() async {
        let (repository, reminders, inbox, store) = fixture()
        reminders.failSchedule = true
        await store.receive(action(repository.values[0], .snooze))
        XCTAssertEqual(inbox.values.count, 1)
        XCTAssertTrue(store.active!.events.isEmpty)
        reminders.failSchedule = false
        await store.refresh()
        XCTAssertTrue(inbox.values.isEmpty)
        XCTAssertNotNil(reminders.state.snooze)
    }

    func testDeniedOrExpiredSnoozeIsNotResurrected() async {
        let (repository, reminders, _, store) = fixture()
        let denied = action(repository.values[0], .snooze)
        reminders.state.allowed = false
        await store.receive(denied)
        XCTAssertEqual(store.operational, "Notifications blocked")
        reminders.state.allowed = true
        await store.receive(denied)
        var expired = action(repository.values[0], .snooze)
        expired.date = time.addingTimeInterval(-700)
        await store.receive(expired)
        XCTAssertNil(reminders.state.snooze)
        XCTAssertEqual(reminders.scheduleCount, 0)
    }

    func testActionDuringResumeIsQueuedThenPauseWins() async {
        let (repository, reminders, inbox, store) = fixture()
        await store.pause()
        let command = action(repository.values[0], .pause)
        reminders.duringSchedule = { await store.receive(command) }
        await store.resume()
        XCTAssertEqual(store.active?.state, .paused)
        XCTAssertEqual(store.active?.pauseReason, "notification")
        XCTAssertNil(reminders.state.sessionID)
        XCTAssertTrue(inbox.values.isEmpty)
    }

    func testActionDuringFinalReconciliationDrainsBeforeBecomingIdle() async {
        let (repository, reminders, inbox, store) = fixture()
        let command = action(repository.values[0], .pause)
        reminders.duringSnapshot = { await store.receive(command) }
        await store.refresh()
        XCTAssertEqual(store.active?.state, .paused)
        XCTAssertEqual(store.operational, "Paused")
        XCTAssertNil(reminders.state.sessionID)
        XCTAssertTrue(inbox.values.isEmpty)
    }

    func testQueuedDoneMergesBeforeEndAndLateActionsCannotReviveIt() async throws {
        let (repository, reminders, inbox, store) = fixture()
        let active = repository.values[0]
        try inbox.enqueue(action(active))
        await store.end()
        XCTAssertNil(store.active)
        XCTAssertEqual(store.summary?.count, 1)
        await store.receive(action(active))
        await store.receive(action(active, .snooze))
        XCTAssertEqual(store.todayCount, 1)
        XCTAssertNil(reminders.state.sessionID)
        XCTAssertNil(reminders.state.snooze)
    }

    func testInboxFailureDoesNotClaimCompletion() async {
        let (repository, _, inbox, store) = fixture()
        inbox.failEnqueue = true
        await store.receive(action(repository.values[0]))
        XCTAssertEqual(store.todayCount, 0)
        XCTAssertTrue(store.message?.contains("could not be saved") == true)
    }

    func testResumeDoesNotResetHealthyCadenceAndOldCategoryNeedsRepair() async {
        let (_, reminders, _, store) = fixture()
        await store.resume()
        XCTAssertEqual(reminders.scheduleCount, 0)
        reminders.state.actionable = false
        await store.refresh()
        XCTAssertEqual(store.operational, "Reminder needs repair")
        await store.resume()
        XCTAssertEqual(reminders.scheduleCount, 1)
        XCTAssertEqual(store.operational, "Running")
    }

    func testCategoryOrderAndRouterRejectUnrelatedOrDefaultActions() throws {
        let category = ReminderService.category()
        XCTAssertEqual(category.actions.map(\.identifier), [ReminderService.doneAction, ReminderService.pauseAction, ReminderService.snoozeAction])
        XCTAssertTrue(category.actions.allSatisfy { $0.options.isEmpty })
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = ReminderService.categoryID
        content.userInfo = ["session": session().id.uuidString]
        let request = UNNotificationRequest(identifier: ReminderService.regular, content: content, trigger: nil)
        let a = try XCTUnwrap(AppNotificationCoordinator.action(request: request, delivered: time, identifier: ReminderService.doneAction, now: time))
        let duplicate = try XCTUnwrap(AppNotificationCoordinator.action(request: request, delivered: time, identifier: ReminderService.doneAction, now: time.addingTimeInterval(1)))
        let later = try XCTUnwrap(AppNotificationCoordinator.action(request: request, delivered: time.addingTimeInterval(2700), identifier: ReminderService.doneAction, now: time))
        XCTAssertEqual(a.id, duplicate.id)
        XCTAssertNotEqual(a.id, later.id)
        XCTAssertNil(AppNotificationCoordinator.action(request: request, delivered: time, identifier: UNNotificationDefaultActionIdentifier))
        XCTAssertNil(AppNotificationCoordinator.action(request: request, delivered: time, identifier: UNNotificationDismissActionIdentifier))
        let foreign = UNNotificationRequest(identifier: "other-feature", content: content, trigger: nil)
        XCTAssertNil(AppNotificationCoordinator.action(request: foreign, delivered: time, identifier: ReminderService.doneAction))
    }

    func testFileInboxSurvivesRecreationDeduplicatesAndPreservesCorruption() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("inbox.json")
        var writes = 0
        let inbox = FileSquatActionInbox(url: url) { data, target, options in
            XCTAssertTrue(options.contains(.atomic))
            XCTAssertTrue(options.contains(.completeFileProtectionUntilFirstUserAuthentication))
            writes += 1
            try data.write(to: target, options: options)
        }
        let command = action(session())
        try inbox.enqueue(command)
        try inbox.enqueue(command)
        XCTAssertEqual(writes, 1)
        let reopened = FileSquatActionInbox(url: url)
        XCTAssertEqual(try reopened.pending(), [command])
        #if !targetEnvironment(simulator)
        // Simulator returns no file-protection metadata. Actual protection is a device gate.
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .completeUntilFirstUserAuthentication)
        #endif
        try Data("corrupt".utf8).write(to: url)
        XCTAssertThrowsError(try reopened.enqueue(command))
        XCTAssertEqual(try Data(contentsOf: url), Data("corrupt".utf8))
    }

    func testFailedFileReplacementPreservesPreviouslyQueuedActions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("inbox.json")
        let initial = FileSquatActionInbox(url: url)
        let command = action(session())
        try initial.enqueue(command)
        let failing = FileSquatActionInbox(url: url) { _, _, _ in throw CocoaError(.fileWriteOutOfSpace) }
        XCTAssertThrowsError(try failing.enqueue(action(session())))
        XCTAssertThrowsError(try failing.remove(command.id))
        XCTAssertEqual(try FileSquatActionInbox(url: url).pending(), [command])
    }

    func testLegacyPayloadDecodesAndDiskRestartKeepsReceiptAfterUndo() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let schema = Schema(versionedSchema: SquatSchemaV1.self)
        let config = ModelConfiguration("ActionDiskTest", schema: schema, url: root.appendingPathComponent("store.sqlite"))
        var original = session()
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy.removeValue(forKey: "actionReceipts")
        legacy.removeValue(forKey: "pauseReason")
        original = try JSONDecoder().decode(SquatSession.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(original.actionReceipts)
        let command = action(original)
        original = command.applying(to: original)
        original.undo()
        do {
            let container = try ModelContainer(for: schema, migrationPlan: SquatMigration.self, configurations: [config])
            try SwiftDataSquatRepository(container: container).save(original)
        }
        let reopened = try ModelContainer(for: schema, migrationPlan: SquatMigration.self, configurations: [config])
        let saved = try XCTUnwrap(SwiftDataSquatRepository(container: reopened).load().first)
        XCTAssertEqual(saved.count, 0)
        XCTAssertEqual(saved.actionReceipts, [command.id])
        XCTAssertEqual(command.applying(to: saved).count, 0)
    }
}
