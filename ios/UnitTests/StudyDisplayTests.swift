import XCTest
import SwiftData
import SwiftUI
@testable import AkshatOS

@MainActor final class StudyDisplayTests: XCTestCase {
    func testKeepAwakeRestoresOnPauseInactivityAndExitWithoutChangingStudyTime() {
        var idleDisabled = false
        let display = StudyDisplayController(readIdleTimer: { idleDisabled }, writeIdleTimer: { idleDisabled = $0 })
        display.update(visible: true, active: true, running: true, enabled: false)
        XCTAssertFalse(idleDisabled)
        display.update(visible: true, active: true, running: true, enabled: true)
        XCTAssertTrue(idleDisabled)
        display.update(visible: true, active: false, running: true, enabled: true)
        XCTAssertFalse(idleDisabled, "Control Center, a call or locking releases the foreground sleep override")
        display.update(visible: true, active: true, running: true, enabled: true)
        XCTAssertTrue(idleDisabled)
        display.update(visible: true, active: true, running: false, enabled: true)
        XCTAssertFalse(idleDisabled, "A paused block cannot keep the phone awake")
        display.update(visible: true, active: true, running: true, enabled: true)
        display.release(); display.release()
        XCTAssertFalse(idleDisabled, "Leaving Focus restores auto-lock idempotently")
    }

    func testKeepAwakePreservesAnExistingSleepOverride() {
        var idleDisabled = true
        let display = StudyDisplayController(readIdleTimer: { idleDisabled }, writeIdleTimer: { idleDisabled = $0 })
        display.update(visible: true, active: true, running: true, enabled: true)
        display.update(visible: false, active: true, running: true, enabled: true)
        XCTAssertTrue(idleDisabled)
    }

    func testReadingAndStudyRotationOwnersCannotDisableEachOther() {
        let orientation = OrientationGate()
        XCTAssertEqual(orientation.supportedOrientations, .portrait)
        orientation.setStudyFocusSession(true)
        XCTAssertTrue(orientation.supportedOrientations.contains(.landscapeLeft))
        orientation.setReadingSession(true)
        orientation.setStudyFocusSession(false)
        XCTAssertTrue(orientation.supportedOrientations.contains(.landscapeRight))
        orientation.setReadingSession(false)
        XCTAssertEqual(orientation.supportedOrientations, .portrait)
    }

    func testClockProjectionIncludesEarlierBlocksAndStopsAtDayBoundary() {
        let anchor = Date(timeIntervalSince1970: 10000)
        let state = StudyActivityAttributes.ContentState(anchor: anchor, studiedAtAnchor: 3600,
            target: 21600, validUntil: anchor.addingTimeInterval(120))
        XCTAssertEqual(state.studied(at: anchor.addingTimeInterval(60)), 3660)
        XCTAssertEqual(state.studied(at: anchor.addingTimeInterval(3600)), 3720)
        XCTAssertEqual(state.elapsedOrigin, anchor.addingTimeInterval(-3600))
        XCTAssertEqual(state.targetDate, anchor.addingTimeInterval(18000))
        let reached = StudyActivityAttributes.ContentState(anchor: anchor, studiedAtAnchor: 22000, target: 21600, validUntil: anchor.addingTimeInterval(120))
        XCTAssertEqual(reached.remainingRange.lowerBound, reached.remainingRange.upperBound)
    }

    func testInactivityAndActivityFailureNeverStopOrRewriteTheStudyBlock() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.study.start()
        let running = try XCTUnwrap(fixture.study.log.running)
        fixture.client.failStart = true
        fixture.activity.enabled = true
        await fixture.activity.waitForPendingUpdates()
        XCTAssertTrue(fixture.study.isRunning)
        XCTAssertEqual(fixture.study.log.running?.id, running.id)
        XCTAssertTrue(fixture.activity.status.contains("could not start"))
        fixture.foreground = false
        fixture.now = fixture.now.addingTimeInterval(3600)
        fixture.activity.showAgain()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertEqual(fixture.study.currentBlock(at: fixture.now), 3600)
        XCTAssertEqual(fixture.study.log.running?.start, running.start)
        XCTAssertTrue(fixture.activity.status.contains("Open AkshatOS"))
    }

    func testSingleActivityPauseResumeAndDeniedAuthorizationAreIndependentOfRecording() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.study.start(); fixture.activity.enabled = true
        await fixture.activity.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.activities.count, 1)
        fixture.activity.reconcile(); fixture.activity.reconcile()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.startCount, 1)
        fixture.now = fixture.now.addingTimeInterval(60)
        fixture.study.pause(); fixture.activity.reconcile()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertTrue(fixture.client.activities.isEmpty)
        fixture.study.start(); fixture.client.allowed = false; fixture.activity.reconcile()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertTrue(fixture.study.isRunning)
        XCTAssertTrue(fixture.client.activities.isEmpty)
        fixture.client.allowed = true; fixture.activity.reconcile()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.activities.count, 1)
        XCTAssertEqual(fixture.study.studiedToday(at: fixture.now), 60)
    }

    func testDismissedActivityDoesNotReappearUntilAnExplicitRequest() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.study.start(); fixture.activity.enabled = true
        await fixture.activity.waitForPendingUpdates()
        fixture.client.activities = [] // Person swiped it away, or the system ended it.
        fixture.activity.reconcile()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.startCount, 1)
        XCTAssertTrue(fixture.study.isRunning)
        let reopened = StudyLiveActivityCoordinator(study: fixture.study, defaults: fixture.defaults, configured: true, client: fixture.client, isForeground: { true })
        reopened.reconcile(); await reopened.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.startCount, 1, "A relaunched app must respect dismissal of this block's card")
        fixture.activity.showAgain()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.startCount, 2)
    }

    func testColdLaunchBeforeStoreLoadCannotEraseDismissalOrEndAnExistingCard() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.study.start(); fixture.activity.enabled = true
        await fixture.activity.waitForPendingUpdates()
        let unloaded = StudyLogStore(repository: fixture.repository, defaults: fixture.defaults, now: { fixture.now })
        let reopened = StudyLiveActivityCoordinator(study: unloaded, defaults: fixture.defaults, configured: true, client: fixture.client, isForeground: { true })
        reopened.reconcile(); await reopened.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.activities.count, 1, "An empty cache before load is not a paused session")
        fixture.client.activities = []
        unloaded.load(); reopened.reconcile(); await reopened.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.startCount, 1, "Cold launch retains the saved last-shown session")
    }

    func testActivityExpiresAtThreeAMAndEightHoursWithoutStoppingTheSession() async throws {
        let fixture = try Fixture()
        defer { fixture.clean() }
        fixture.now = ISO8601DateFormatter().date(from: "2026-01-02T02:59:00Z")!
        fixture.study.start(); fixture.activity.enabled = true
        await fixture.activity.waitForPendingUpdates()
        XCTAssertEqual(fixture.client.state?.validUntil.timeIntervalSince(fixture.now), 60)
        fixture.now = fixture.now.addingTimeInterval(120)
        fixture.activity.reconcile()
        await fixture.activity.waitForPendingUpdates()
        // The foreground app can reconcile the next day's projection using the same saved block.
        XCTAssertEqual(fixture.client.state?.studiedAtAnchor, 60)
        XCTAssertTrue(fixture.study.isRunning)
        fixture.now = fixture.now.addingTimeInterval(8 * 3600)
        fixture.activity.reconcile()
        await fixture.activity.waitForPendingUpdates()
        XCTAssertTrue(fixture.client.activities.isEmpty)
        XCTAssertTrue(fixture.study.isRunning)
    }
}

@MainActor private final class FakeStudyActivityClient: StudyActivityClient {
    var allowed = true
    var activities: [StudyActivityHandle] = []
    var startCount = 0
    var failStart = false
    var state: StudyActivityAttributes.ContentState?
    func start(sessionID: UUID, state: StudyActivityAttributes.ContentState) throws {
        if failStart { throw CocoaError(.featureUnsupported) }
        startCount += 1; self.state = state
        activities = [StudyActivityHandle(id: UUID().uuidString, sessionID: sessionID, createdAt: state.anchor)]
    }
    func update(_ handle: StudyActivityHandle, state: StudyActivityAttributes.ContentState) async { self.state = state }
    func end(_ handle: StudyActivityHandle) async { activities.removeAll { $0.id == handle.id } }
}

@MainActor private final class Fixture {
    let suite = "study-display-" + UUID().uuidString
    let defaults: UserDefaults
    let repository: SwiftDataStudyLogRepository
    let client = FakeStudyActivityClient()
    var now = ISO8601DateFormatter().date(from: "2026-01-01T12:00:00Z")!
    var foreground = true
    var study: StudyLogStore!
    var activity: StudyLiveActivityCoordinator!
    init() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let schema = Schema(versionedSchema: StudyLogSchemaV1.self)
        let db = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        repository = SwiftDataStudyLogRepository(container: db)
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        study = StudyLogStore(repository: repository, defaults: defaults, now: { [unowned self] in self.now }, calendar: calendar)
        study.load()
        activity = StudyLiveActivityCoordinator(study: study, defaults: defaults, configured: true, client: client, isForeground: { [unowned self] in self.foreground })
    }
    func clean() { defaults.removePersistentDomain(forName: suite) }
}
