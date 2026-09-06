import XCTest
import SwiftData
import UserNotifications
@testable import AkshatOS

@MainActor private final class MemoryRepository: SquatRepository {
    var values: [SquatSession] = []
    var unavailable = false
    var failSave = false
    var failReplace = false
    func load() throws -> [SquatSession] {
        if unavailable { throw CocoaError(.fileReadNoPermission) }
        return values
    }
    func save(_ session: SquatSession) throws {
        if failSave || unavailable { throw CocoaError(.fileWriteNoPermission) }
        values.removeAll { $0.id == session.id }
        values.append(session)
    }
    func replaceAll(with sessions: [SquatSession]) throws {
        if failReplace || unavailable { throw CocoaError(.fileWriteNoPermission) }
        values = sessions
    }
    func delete(ids: Set<UUID>) throws {
        if failSave || unavailable { throw CocoaError(.fileWriteNoPermission) }
        values.removeAll { ids.contains($0.id) }
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
    var state = ReminderSnapshot(allowed: true, authorization: .authorized)
    var scheduleCount = 0
    var failSchedule = false
    var cancelSnoozeCount = 0
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
        if let date = snoozeUntil {
            state.hasSnooze = true
            state.snoozeSessionID = session.id
            state.snoozeActionable = true
            state.snooze = date
        }
        else {
            state.sessionID = session.id
            state.interval = TimeInterval(session.interval * 60)
            state.actionable = true
            state.next = Date().addingTimeInterval(TimeInterval(session.interval * 60))
        }
    }
    func cancel() {
        state.sessionID = nil; state.interval = nil; state.next = nil
        state.hasSnooze = false; state.snoozeSessionID = nil; state.snooze = nil
    }
    func cancelSnooze() {
        cancelSnoozeCount += 1
        state.hasSnooze = false; state.snoozeSessionID = nil; state.snooze = nil
    }
}

@MainActor private final class MemoryHomePersistence: HomeAutomationPersistence {
    var value: HomeAutomationState?
    func load() throws -> HomeAutomationState? { value }
    func save(_ state: HomeAutomationState) throws { value = state }
    func delete() throws { value = nil }
}

@MainActor private final class MemoryHomeInbox: HomeEventInbox {
    var values: [HomeBoundaryEvent] = []
    func pending() throws -> [HomeBoundaryEvent] { values }
    func enqueue(_ event: HomeBoundaryEvent) throws {
        if !values.contains(where: { $0.id == event.id }) { values.append(event) }
    }
    func remove(_ id: String) throws { values.removeAll { $0.id == id } }
}

@MainActor private final class FakeHomeMonitor: HomeRegionMonitoring {
    var eventHandler: ((HomeBoundaryEvent) -> Void)?
    var failureHandler: ((String) -> Void)?
    var state = HomeRegionSnapshot(authorization: .always, monitoringAvailable: true,
        monitoredBoundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150),
        backgroundAccess: .available)
    var startCount = 0
    func requestWhenInUse() async -> HomeAuthorization { state.authorization }
    func requestAlways() async -> HomeAuthorization { state.authorization }
    func currentLocation() async throws -> (latitude: Double, longitude: Double) { (41.0, -87.0) }
    func snapshot() -> HomeRegionSnapshot { state }
    func startMonitoring(_ boundary: HomeBoundary) throws {
        startCount += 1
        state.monitoredBoundary = boundary
    }
    func stopMonitoring() { state.monitoredBoundary = nil }
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
                      _ inbox: any SquatActionInbox,
                      home: MemoryHomePersistence? = nil,
                      homeInbox: MemoryHomeInbox? = nil,
                      monitor: FakeHomeMonitor? = nil,
                      defaults: UserDefaults? = nil) -> SquatStore {
        let clock = time
        let resolvedDefaults = defaults ?? UserDefaults(suiteName: "SquatsActionTests.\(UUID().uuidString)")!
        return SquatStore(defaults: resolvedDefaults, repository: repository, reminders: reminders,
                          inbox: inbox, homePersistence: home ?? MemoryHomePersistence(),
                          homeInbox: homeInbox ?? MemoryHomeInbox(),
                          homeMonitor: monitor ?? FakeHomeMonitor(), now: { clock })
    }

    func testHomeExitPausesAndMatchingEntryResumesSameDay() async {
        let repository = MemoryRepository(); repository.values = [session()]
        let reminders = FakeReminders(); reminders.state.sessionID = repository.values[0].id; reminders.state.interval = 2700
        let home = MemoryHomePersistence()
        home.value = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150), presence: .inside)
        let store = make(repository, reminders, MemoryInbox(), home: home)
        await store.receive(HomeBoundaryEvent(kind: .exited, date: time,
            regionIdentifier: HomeAutomationState.regionIdentifier))
        XCTAssertEqual(store.active?.state, .paused)
        XCTAssertEqual(store.active?.pauseReason, "homeAwayAutomation")
        XCTAssertNil(reminders.state.sessionID)
        await store.receive(HomeBoundaryEvent(kind: .entered, date: time.addingTimeInterval(180),
            regionIdentifier: HomeAutomationState.regionIdentifier))
        XCTAssertEqual(store.active?.state, .running)
        XCTAssertNil(store.active?.pauseReason)
        XCTAssertEqual(reminders.state.sessionID, store.active?.id)
    }

    func testDeliberatePauseWhileAwayPreventsArrivalResume() async {
        let repository = MemoryRepository(); repository.values = [session()]
        let reminders = FakeReminders(); reminders.state.sessionID = repository.values[0].id; reminders.state.interval = 2700
        let home = MemoryHomePersistence()
        home.value = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150), presence: .inside)
        let store = make(repository, reminders, MemoryInbox(), home: home)
        await store.receive(HomeBoundaryEvent(kind: .exited, date: time,
            regionIdentifier: HomeAutomationState.regionIdentifier))
        await store.pause()
        XCTAssertEqual(store.active?.pauseReason, "dashboard")
        await store.receive(HomeBoundaryEvent(kind: .entered, date: time.addingTimeInterval(180),
            regionIdentifier: HomeAutomationState.regionIdentifier))
        XCTAssertEqual(store.active?.state, .paused)
        XCTAssertNil(reminders.state.sessionID)
    }

    func testManualResumeOutsideSuppressesExitUntilEntryOrEnd() async {
        let repository = MemoryRepository(); var paused = session(); paused.state = .paused; paused.pauseReason = "dashboard"; repository.values = [paused]
        let reminders = FakeReminders()
        let home = MemoryHomePersistence()
        home.value = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150), presence: .outside)
        let store = make(repository, reminders, MemoryInbox(), home: home)
        await store.resume()
        XCTAssertTrue(home.value!.suppressExitUntilEntry)
        await store.receive(HomeBoundaryEvent(kind: .exited, date: time.addingTimeInterval(180),
            regionIdentifier: HomeAutomationState.regionIdentifier))
        XCTAssertEqual(store.active?.state, .running)
        await store.end()
        XCTAssertFalse(home.value!.suppressExitUntilEntry)
    }

    func testSameDayGoalSnapshotSurvivesSettingChangeAndRestart() async {
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        let inbox = MemoryInbox()
        let store = make(repository, reminders, inbox)
        store.goal = 4
        await store.start()
        await store.end()
        store.goal = 8
        await store.start()
        XCTAssertEqual(store.todayGoal, 4)
        XCTAssertEqual(store.active?.goal, 4)
    }
    private func fixture() -> (MemoryRepository, FakeReminders, MemoryInbox, SquatStore) {
        let repository = MemoryRepository()
        repository.values = [session()]
        let reminders = FakeReminders()
        reminders.state.sessionID = repository.values[0].id
        reminders.state.interval = 2700
        reminders.state.next = time.addingTimeInterval(2700)
        let inbox = MemoryInbox()
        return (repository, reminders, inbox, make(repository, reminders, inbox))
    }

    func testInitializationRepairsInvalidIdlePreferences() {
        let suite = "SquatsActionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(-50, forKey: "squats.interval")
        defaults.set(500, forKey: "squats.goal")
        let store = make(MemoryRepository(), FakeReminders(), MemoryInbox(), defaults: defaults)
        XCTAssertEqual(store.interval, 1)
        XCTAssertEqual(store.goal, 100)
        XCTAssertEqual(defaults.integer(forKey: "squats.interval"), 1)
        XCTAssertEqual(defaults.integer(forKey: "squats.goal"), 100)
    }

    func testFreshPreferencesUseChosenDefaultsAndPreserveExplicitGoalOff() {
        let suite = "SquatsActionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = make(MemoryRepository(), FakeReminders(), MemoryInbox(), defaults: defaults)
        XCTAssertEqual(store.interval, SquatStore.defaultInterval)
        XCTAssertEqual(store.goal, SquatStore.defaultGoal)
        XCTAssertEqual(defaults.integer(forKey: "squats.interval"), 45)
        XCTAssertEqual(defaults.integer(forKey: "squats.goal"), 8)

        defaults.set(0, forKey: "squats.goal")
        let reopened = make(MemoryRepository(), FakeReminders(), MemoryInbox(), defaults: defaults)
        XCTAssertEqual(reopened.goal, 0, "An explicit choice to turn goal tracking off must survive relaunch")
    }

    func testHomeDraftUsesChosenDefaultRadiusAndClampsEdits() async {
        let monitor = FakeHomeMonitor()
        let store = make(MemoryRepository(), FakeReminders(), MemoryInbox(), monitor: monitor)
        await store.chooseCurrentLocationAsHome()
        XCTAssertEqual(store.homeDraft?.radius, HomeBoundary.defaultRadius)
        XCTAssertEqual(HomeBoundary.defaultRadius, 150)
        store.updateHomeDraftRadius(10)
        XCTAssertEqual(store.homeDraft?.radius, HomeBoundary.allowedRadius.lowerBound)
        store.updateHomeDraftRadius(2_000)
        XCTAssertEqual(store.homeDraft?.radius, HomeBoundary.allowedRadius.upperBound)
    }

    func testLifecycleIsIdempotentAndSnapshotsActiveSettings() async {
        let suite = "SquatsActionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(30, forKey: "squats.interval")
        defaults.set(6, forKey: "squats.goal")
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        let store = make(repository, reminders, MemoryInbox(), defaults: defaults)

        await store.start()
        await store.start()
        XCTAssertEqual(reminders.scheduleCount, 1)
        XCTAssertEqual(store.active?.state, .running)
        XCTAssertEqual(store.active?.interval, 30)
        XCTAssertEqual(store.active?.goal, 6)

        store.interval = 60
        store.goal = 10
        await store.pause()
        await store.pause()
        XCTAssertEqual(store.active?.events.filter { $0.kind == .pause }.count, 1)
        XCTAssertEqual(store.active?.interval, 30)
        XCTAssertEqual(store.active?.goal, 6)
        XCTAssertNil(reminders.state.sessionID)

        await store.resume()
        await store.resume()
        XCTAssertEqual(reminders.scheduleCount, 2)
        XCTAssertEqual(reminders.state.interval, 1_800)
        await store.end()
        await store.end()
        XCTAssertNil(store.active)
        XCTAssertEqual(store.summary?.goal, 6)
        XCTAssertNil(reminders.state.sessionID)
    }

    func testStartSchedulingFailureLeavesRecoverablePausedDay() async {
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        reminders.failSchedule = true
        let store = make(repository, reminders, MemoryInbox())
        await store.start()
        XCTAssertEqual(store.active?.state, .paused)
        XCTAssertEqual(store.operational, "Paused")
        XCTAssertNil(reminders.state.sessionID)
        XCTAssertNotNil(store.message)

        reminders.failSchedule = false
        await store.resume()
        XCTAssertEqual(store.active?.state, .running)
        XCTAssertEqual(store.operational, "Running")
        XCTAssertEqual(reminders.scheduleCount, 1)
    }

    func testPausedAndCompletedStatesCancelUnexpectedRequests() async {
        let pausedRepository = MemoryRepository()
        var paused = session(); paused.state = .paused
        pausedRepository.values = [paused]
        let pausedReminders = FakeReminders()
        pausedReminders.state.sessionID = paused.id
        pausedReminders.state.interval = 2_700
        pausedReminders.state.next = time.addingTimeInterval(2_700)
        pausedReminders.state.hasSnooze = true
        pausedReminders.state.snoozeSessionID = paused.id
        pausedReminders.state.snooze = time.addingTimeInterval(600)
        let pausedStore = make(pausedRepository, pausedReminders, MemoryInbox())
        await pausedStore.refresh()
        XCTAssertEqual(pausedStore.operational, "Paused")
        XCTAssertNil(pausedReminders.state.sessionID)
        XCTAssertFalse(pausedReminders.state.hasSnooze)

        let endedRepository = MemoryRepository()
        var ended = session(); ended.state = .ended; ended.ended = time
        endedRepository.values = [ended]
        let endedReminders = FakeReminders()
        endedReminders.state.sessionID = ended.id
        endedReminders.state.next = time.addingTimeInterval(2_700)
        let endedStore = make(endedRepository, endedReminders, MemoryInbox())
        await endedStore.refresh()
        XCTAssertEqual(endedStore.operational, "Day complete")
        XCTAssertNil(endedReminders.state.sessionID)
    }

    func testRepairRearmsRunningSessionWhenTriggerHasNoNextDate() async {
        let (_, reminders, _, store) = fixture()
        reminders.state.next = nil
        await store.refresh()
        XCTAssertEqual(store.operational, "Reminder needs repair")
        await store.resume()
        XCTAssertEqual(reminders.scheduleCount, 1)
        XCTAssertEqual(store.operational, "Running")
        XCTAssertNotNil(store.nextReminder)
    }

    func testForegroundAndRelaunchKeepPersistedCadenceInsteadOfResettingFromTriggerSnapshot() async {
        let repository = MemoryRepository()
        var active = session()
        let originalDeadline = time.addingTimeInterval(1_200)
        active.reminderCadenceAnchor = originalDeadline
        repository.values = [active]
        let reminders = FakeReminders()
        reminders.state.sessionID = active.id
        reminders.state.interval = 2_700
        reminders.state.next = time.addingTimeInterval(2_700)

        let first = make(repository, reminders, MemoryInbox())
        await first.refresh()
        XCTAssertEqual(first.nextReminder, originalDeadline)

        reminders.state.next = time.addingTimeInterval(5_400)
        let reopened = make(repository, reminders, MemoryInbox())
        await reopened.refresh()
        XCTAssertEqual(reopened.nextReminder, originalDeadline,
                       "Closing and reopening must not restart the displayed interval")
    }

    func testSnoozeOwnsPrimaryCountdownAndDashboardTimelineContainsOnlyCompletions() async {
        let (repository, reminders, _, _) = fixture()
        var active = repository.values[0]
        active.log(SquatEvent(date: time.addingTimeInterval(-120), kind: .pause, source: "dashboard"))
        active.log(SquatEvent(date: time.addingTimeInterval(-60), kind: .done, source: "dashboard"))
        repository.values = [active]
        let snooze = time.addingTimeInterval(600)
        reminders.state.hasSnooze = true
        reminders.state.snoozeSessionID = active.id
        reminders.state.snooze = snooze

        let reopened = make(repository, reminders, MemoryInbox())
        await reopened.refresh()
        XCTAssertTrue(reopened.primaryReminderIsSnooze)
        XCTAssertEqual(reopened.primaryReminder, snooze)
        XCTAssertEqual(reopened.todayCompletions.map(\.kind), [.done])
    }

    func testLegacyRunningSessionAdoptsTriggerDeadlineOnlyOnce() async {
        let (repository, reminders, _, store) = fixture()
        let adopted = time.addingTimeInterval(900)
        reminders.state.next = adopted
        await store.refresh()
        XCTAssertEqual(store.nextReminder, adopted)
        XCTAssertEqual(repository.values[0].reminderCadenceAnchor, adopted)

        reminders.state.next = time.addingTimeInterval(2_700)
        let reopened = make(repository, reminders, MemoryInbox())
        await reopened.refresh()
        XCTAssertEqual(reopened.nextReminder, adopted)
    }

    func testForegroundRemovesExpiredAndNonActionableCurrentSnoozes() async {
        let (repository, reminders, _, store) = fixture()
        reminders.state.hasSnooze = true
        reminders.state.snoozeSessionID = repository.values[0].id
        reminders.state.snooze = time.addingTimeInterval(-1)
        await store.refresh()
        XCTAssertEqual(reminders.cancelSnoozeCount, 1)

        reminders.state.hasSnooze = true
        reminders.state.snoozeSessionID = repository.values[0].id
        reminders.state.snoozeActionable = false
        reminders.state.snooze = time.addingTimeInterval(600)
        await store.refresh()
        XCTAssertEqual(reminders.cancelSnoozeCount, 2)
        XCTAssertNil(store.snoozeReminder)
        XCTAssertEqual(store.operational, "Running")
    }

    func testAuthorizedButAlertsDisabledBlocksRunningAndRemovesSnooze() async {
        let (repository, reminders, _, store) = fixture()
        reminders.state.authorization = .authorized
        reminders.state.allowed = false
        reminders.state.hasSnooze = true
        reminders.state.snoozeSessionID = repository.values[0].id
        reminders.state.snooze = time.addingTimeInterval(600)
        await store.refresh()
        XCTAssertTrue(store.notificationEverAuthorized)
        XCTAssertEqual(store.notificationAuthorization, .authorized)
        XCTAssertEqual(store.operational, "Notifications blocked")
        XCTAssertEqual(reminders.cancelSnoozeCount, 1)
    }

    func testHomeHealthCoversInsufficientAuthorizationSystemAndBackgroundFailures() async {
        let home = MemoryHomePersistence()
        home.value = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150))
        let monitor = FakeHomeMonitor()
        monitor.state.authorization = .whenInUse
        let store = make(MemoryRepository(), FakeReminders(), MemoryInbox(), home: home, monitor: monitor)
        await store.refresh()
        XCTAssertEqual(store.homeHealth, "Always access needed")

        monitor.state.authorization = .always
        monitor.state.monitoringAvailable = false
        await store.refresh()
        XCTAssertEqual(store.homeHealth, "Region monitoring unavailable")

        monitor.state.monitoringAvailable = true
        monitor.state.backgroundAccess = .denied
        await store.refresh()
        XCTAssertEqual(store.homeHealth, "Background refresh restricted")
    }

    func testDisableHomeClearsEventsAndPreventsAutomationResume() async throws {
        let repository = MemoryRepository()
        var paused = session(); paused.state = .paused; paused.pauseReason = "homeAwayAutomation"
        repository.values = [paused]
        let home = MemoryHomePersistence()
        home.value = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150),
                                         presence: .outside)
        let homeInbox = MemoryHomeInbox()
        try homeInbox.enqueue(HomeBoundaryEvent(kind: .entered, date: time,
            regionIdentifier: HomeAutomationState.regionIdentifier))
        let monitor = FakeHomeMonitor()
        let store = make(repository, FakeReminders(), MemoryInbox(), home: home,
                         homeInbox: homeInbox, monitor: monitor)
        await store.disableHome()
        XCTAssertFalse(store.homeEnabled)
        XCTAssertNil(home.value)
        XCTAssertTrue(homeInbox.values.isEmpty)
        XCTAssertNil(monitor.state.monitoredBoundary)
        XCTAssertEqual(store.active?.pauseReason, "homeAutomationDisabled")
    }

    func testForegroundReconciliationRemovesForeignSnoozeButPreservesHealthyCadence() async {
        let (repository, reminders, _, store) = fixture()
        reminders.state.hasSnooze = true
        reminders.state.snoozeSessionID = UUID()
        reminders.state.snooze = time.addingTimeInterval(600)
        await store.refresh()
        XCTAssertEqual(store.operational, "Running")
        XCTAssertEqual(reminders.state.sessionID, repository.values[0].id)
        XCTAssertEqual(reminders.cancelSnoozeCount, 1)
        XCTAssertNil(store.snoozeReminder)
    }

    func testForegroundReconciliationKeepsValidCurrentSessionSnooze() async {
        let (repository, reminders, _, store) = fixture()
        let deadline = time.addingTimeInterval(600)
        reminders.state.hasSnooze = true
        reminders.state.snoozeSessionID = repository.values[0].id
        reminders.state.snooze = deadline
        await store.refresh()
        XCTAssertEqual(store.operational, "Running")
        XCTAssertEqual(reminders.cancelSnoozeCount, 0)
        XCTAssertEqual(store.snoozeReminder, deadline)
    }

    func testForegroundReconciliationReplacesMismatchedHomeBoundaryAndForgetsPresence() async {
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        let home = MemoryHomePersistence()
        let expected = HomeBoundary(latitude: 41, longitude: -87, radius: 250)
        home.value = HomeAutomationState(boundary: expected, presence: .outside,
                                         lastEventDate: time.addingTimeInterval(-300))
        let monitor = FakeHomeMonitor()
        monitor.state.monitoredBoundary = HomeBoundary(latitude: 42, longitude: -88, radius: 100)
        let store = make(repository, reminders, MemoryInbox(), home: home, monitor: monitor)
        await store.refresh()
        XCTAssertEqual(monitor.startCount, 1)
        XCTAssertEqual(monitor.state.monitoredBoundary, expected)
        XCTAssertEqual(home.value?.presence, .unknown)
        XCTAssertNil(home.value?.lastEventDate)
        XCTAssertEqual(store.homeHealth, "Checking Home boundary")
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
                               homePersistence: MemoryHomePersistence(), homeInbox: MemoryHomeInbox(),
                               homeMonitor: FakeHomeMonitor(),
                               now: { midnight.addingTimeInterval(60) })
        let command = SquatAction(id: UUID().uuidString, sessionID: active.id, kind: .snooze,
                                  date: tap, day: active.day, source: "notification")
        await store.receive(command)
        XCTAssertEqual(reminders.scheduleCount, 0)
        XCTAssertNil(reminders.state.snooze)
        XCTAssertNil(store.active)
        XCTAssertEqual(store.operational, "Ready")
        XCTAssertEqual(store.sessions.first?.ended, midnight)
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
        reminders.state.authorization = .denied
        await store.receive(denied)
        XCTAssertEqual(store.operational, "Notifications blocked")
        XCTAssertEqual(store.notificationAuthorization, .denied)
        reminders.state.allowed = true
        reminders.state.authorization = .authorized
        await store.receive(denied)
        var expired = action(repository.values[0], .snooze)
        expired.date = time.addingTimeInterval(-700)
        await store.receive(expired)
        XCTAssertNil(reminders.state.snooze)
        XCTAssertEqual(reminders.scheduleCount, 0)
    }

    func testStartWithoutNotificationPermissionRoutesMessageToNotificationSettings() async {
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        reminders.state.allowed = false
        reminders.state.authorization = .denied
        let inbox = MemoryInbox()
        let store = make(repository, reminders, inbox)
        await store.start()
        XCTAssertNil(store.active)
        XCTAssertEqual(store.messageRoute, .notifications)
        XCTAssertEqual(store.message, "Allow notifications in iOS Settings before starting your day.")
    }

    func testResumeWithoutNotificationPermissionRoutesMessageToNotificationSettings() async {
        let repository = MemoryRepository()
        var paused = session(); paused.state = .paused; paused.pauseReason = "dashboard"
        repository.values = [paused]
        let reminders = FakeReminders()
        reminders.state.allowed = false
        reminders.state.authorization = .denied
        let store = make(repository, reminders, MemoryInbox())
        await store.resume()
        XCTAssertEqual(store.messageRoute, .notifications)
        XCTAssertEqual(store.active?.state, .paused)
    }

    func testNotificationAuthorizationTracksSnapshotForPermissionUI() async {
        let (_, reminders, _, store) = fixture()
        reminders.state.authorization = .authorized
        await store.refresh()
        XCTAssertEqual(store.notificationAuthorization, .authorized)
        reminders.state.allowed = false
        reminders.state.authorization = .denied
        await store.refresh()
        XCTAssertEqual(store.notificationAuthorization, .denied)
        XCTAssertEqual(store.operational, "Notifications blocked")
    }

    func testHomeAuthorizationDistinguishesDeniedFromRestricted() async {
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        let home = MemoryHomePersistence()
        home.value = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150))
        let monitor = FakeHomeMonitor()
        monitor.state.authorization = .denied
        let store = make(repository, reminders, MemoryInbox(), home: home, monitor: monitor)
        await store.refresh()
        XCTAssertEqual(store.homeAuthorization, .denied)
        XCTAssertEqual(store.homeHealth, "Location access denied")
        monitor.state.authorization = .restricted
        await store.refresh()
        XCTAssertEqual(store.homeAuthorization, .restricted)
        XCTAssertEqual(store.homeHealth, "Location access restricted")
    }

    func testChooseHomeLocationDeniedRoutesMessageToLocationSettings() async {
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        let monitor = FakeHomeMonitor()
        monitor.state.authorization = .denied
        let store = make(repository, reminders, MemoryInbox(), monitor: monitor)
        await store.chooseCurrentLocationAsHome()
        XCTAssertEqual(store.messageRoute, .location)
        XCTAssertEqual(store.homeAuthorization, .denied)
        XCTAssertNil(store.homeDraft)
    }

    func testNotificationRevocationIsRememberedAfterBeingGrantedAndPhrasedDifferentlyThanFirstDenial() async {
        let suite = "SquatsActionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        reminders.state.allowed = false
        reminders.state.authorization = .provisional
        let store = make(repository, reminders, MemoryInbox(), defaults: defaults)
        await store.refresh()
        XCTAssertTrue(store.notificationEverAuthorized)
        reminders.state.authorization = .denied
        let reopened = make(repository, reminders, MemoryInbox(), defaults: defaults)
        await reopened.start()
        XCTAssertTrue(reopened.notificationEverAuthorized, "Revocation must survive store recreation")
        XCTAssertEqual(reopened.message,
            "Notifications were turned off. Allow them again in iOS Settings before starting your day.")
    }

    func testHomeAccessRevocationIsRememberedAfterBeingGrantedAndPhrasedDifferentlyThanFirstDenial() async {
        let suite = "SquatsActionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = MemoryRepository()
        let reminders = FakeReminders()
        let home = MemoryHomePersistence()
        home.value = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 150))
        let monitor = FakeHomeMonitor()
        monitor.state.authorization = .whenInUse
        let store = make(repository, reminders, MemoryInbox(), home: home, monitor: monitor, defaults: defaults)
        await store.refresh()
        XCTAssertTrue(store.homeEverAuthorized)
        monitor.state.authorization = .denied
        let reopened = make(repository, reminders, MemoryInbox(), home: home, monitor: monitor, defaults: defaults)
        await reopened.refresh()
        XCTAssertTrue(reopened.homeEverAuthorized, "Revocation must survive store recreation")
        XCTAssertEqual(reopened.homeHealth, "Location access turned off")
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
        XCTAssertEqual(store.summary?.completedSets, 1)
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

    func testProtectedHomeStateAndEventInboxSurviveRecreation() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let configURL = root.appendingPathComponent("config.json")
        let eventsURL = root.appendingPathComponent("events.json")
        let persistence = FileHomeAutomationPersistence(url: configURL)
        let state = HomeAutomationState(boundary: HomeBoundary(latitude: 41, longitude: -87, radius: 175),
                                        presence: .outside, suppressExitUntilEntry: true)
        try persistence.save(state)
        XCTAssertEqual(try FileHomeAutomationPersistence(url: configURL).load(), state)
        XCTAssertEqual(try configURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertEqual(try root.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        let inbox = FileHomeEventInbox(url: eventsURL)
        let event = HomeBoundaryEvent(id: "home-event", kind: .entered, date: time,
                                      regionIdentifier: HomeAutomationState.regionIdentifier)
        try inbox.enqueue(event)
        try inbox.enqueue(event)
        XCTAssertEqual(try FileHomeEventInbox(url: eventsURL).pending(), [event])
        try persistence.delete()
        XCTAssertNil(try persistence.load())
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

    func testRestoreReplacesHistorySettingsAndLeavesOpenDayNeedingRearm() async throws {
        let (repository, reminders, inbox, store) = fixture()
        try inbox.enqueue(action(repository.values[0], id: "pending-before-restore"))
        var restored = session()
        restored.id = UUID()
        restored.actionReceipts = ["already-recorded"]
        let backup = SquatsBackup(createdAt: time, sessions: [restored], interval: 30, goal: 6)
        await store.restore(backup)
        XCTAssertEqual(repository.values.map(\.id), [restored.id])
        XCTAssertEqual(store.interval, 30)
        XCTAssertEqual(store.goal, 6)
        XCTAssertNil(reminders.state.sessionID)
        XCTAssertEqual(store.operational, "Reminder needs repair")
        XCTAssertTrue(inbox.values.isEmpty)
        XCTAssertEqual(store.active?.actionReceipts, ["already-recorded"])
    }

    func testDeleteHistoryPreservesActiveDayAndSettings() async {
        let (repository, reminders, inbox, _) = fixture()
        var completed = session()
        completed.id = UUID()
        completed.state = .ended
        completed.ended = time
        repository.values.append(completed)
        let store = make(repository, reminders, inbox)
        let interval = store.interval
        await store.deleteHistory()
        XCTAssertEqual(repository.values.map(\.id), [store.active!.id])
        XCTAssertEqual(store.interval, interval)
        XCTAssertEqual(reminders.state.sessionID, store.active?.id)
    }

    func testInvalidBackupNeverReplacesExistingHistory() throws {
        let (repository, reminders, inbox, store) = fixture()
        let existing = repository.values
        let invalid = Data("{\"version\":999}".utf8)
        XCTAssertThrowsError(try store.prepareRestore(invalid))
        XCTAssertEqual(repository.values, existing)
        XCTAssertEqual(reminders.state.sessionID, existing[0].id)
        XCTAssertTrue(inbox.values.isEmpty)
    }
}
