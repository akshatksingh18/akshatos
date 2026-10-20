import SwiftData
import XCTest
@testable import AkshatOS

/// Study Log against a real SwiftData store: blocks saved as they happen, a running block that
/// survives the app being killed, and backups that replace everything or nothing.
@MainActor final class StudyLogPersistenceTests: XCTestCase {
    private var suite: String!
    private var current = Date(timeIntervalSince1970: 1_791_982_800) // 2026-10-14 13:00 UTC
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!
        return value
    }()

    override func setUp() {
        suite = "studylog-tests-\(UUID().uuidString)"
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suite)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: StudyLogSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: StudyLogMigration.self,
                                  configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func makeStore(_ container: ModelContainer) throws -> StudyLogStore {
        let store = StudyLogStore(repository: SwiftDataStudyLogRepository(container: container),
                                  defaults: try XCTUnwrap(UserDefaults(suiteName: suite)),
                                  now: { [unowned self] in current }, calendar: calendar)
        store.load()
        return store
    }

    func testARunningBlockSurvivesTheAppBeingKilled() throws {
        let container = try makeContainer()
        let store = try makeStore(container)
        XCTAssertTrue(store.storageAvailable)
        store.start()
        store.start()
        XCTAssertEqual(store.log.segments.count, 1, "A double tap starts one block")

        current = current.addingTimeInterval(1800)
        let relaunched = try makeStore(container)
        XCTAssertTrue(relaunched.isRunning, "The running block comes back from its saved start")
        XCTAssertEqual(relaunched.studiedToday(at: current), 1800, accuracy: 0.5,
                       "Time kept counting while the app was gone, from the start time alone")

        relaunched.pause()
        let reopened = try makeStore(container)
        XCTAssertFalse(reopened.isRunning)
        XCTAssertEqual(reopened.studiedToday(at: current.addingTimeInterval(3600)), 1800, accuracy: 0.5,
                       "A paused block stays the length it was")
    }

    func testLaptopExchangeSurvivesRelaunchBackupAndRefusesOverlap() throws {
        let container = try makeContainer(), store = try makeStore(container)
        let source = UUID(), id = UUID()
        let payload = StudyExchange(sourceID: source, device: "laptop", revision: 1, exportedAt: current,
            sessions: [.init(id: id, start: current.addingTimeInterval(-3600), end: current.addingTimeInterval(-1800),
                timeZone: "UTC", targetSeconds: 21600, topic: "Read a chapter")])
        let data = try LocalDataCoding.encode(payload)
        XCTAssertTrue(store.importExchange([data]))
        XCTAssertTrue(store.importExchange([data]))
        XCTAssertEqual(store.log.segments.count, 1)
        let reopened = try makeStore(container)
        XCTAssertEqual(reopened.log.segments.first?.exchangeOriginID, source)
        let restored = try makeStore(try makeContainer())
        XCTAssertTrue(restored.restoreBackup(try reopened.backupData()))
        XCTAssertTrue(restored.importExchange([data]))
        XCTAssertEqual(restored.log.segments.count, 1)
        restored.removeSegment(id)
        XCTAssertEqual(restored.log.segments.count, 1, "Imported records cannot be locally removed and replayed")
        var collision = payload
        collision.sessions[0].id = UUID()
        XCTAssertFalse(restored.importExchange([try LocalDataCoding.encode(collision)]))
        XCTAssertEqual(restored.log.segments.count, 1)
        let outward = try LocalDataCoding.decode(StudyExchange.self, restored.exchangeData().data)
        XCTAssertTrue(outward.sessions.isEmpty, "Laptop hours must not be exported as new phone hours")
    }

    func testStartPauseUndoAndCSVUseTheSavedBlocks() throws {
        let store = try makeStore(try makeContainer())
        store.start(); store.undoEdit(); XCTAssertTrue(store.log.segments.isEmpty)
        store.start(); current = current.addingTimeInterval(600); store.pause()
        store.undoEdit(); XCTAssertTrue(store.isRunning, "Undo restores a mistakenly paused timer")
        current = current.addingTimeInterval(30); store.pause()
        XCTAssertEqual(store.log.segments.first?.duration(now: current), 630)
        let csv = try XCTUnwrap(String(data: store.csvData(), encoding: .utf8))
        XCTAssertTrue(csv.contains("630"))
        current = current.addingTimeInterval(11); store.undoEdit()
        XCTAssertFalse(store.isRunning, "Expired Undo cannot reopen an old block")
    }

    func testTopicsRoadmapTypeAndMarksSurviveRelaunch() throws {
        let db = try makeContainer(), store = try makeStore(db)
        store.setDefaultRoadmapType("SQL"); XCTAssertTrue(store.setTopic("Synthetic SQL topic"))
        store.start(); current = current.addingTimeInterval(600); store.pause()
        store.updateSettings(target: 7200, floor: 1800, goal: 3600)
        let reopened = try makeStore(db)
        XCTAssertEqual(reopened.log.segments.first?.roadmapType, "SQL")
        XCTAssertEqual(reopened.log.segments.first?.topic, "Synthetic SQL topic")
        XCTAssertEqual(reopened.targetToday(at: current), 21600, "Changing settings does not rewrite today's first recorded aim")
        let backup = try LocalDataCoding.decode(StudyLogBackup.self, reopened.backupData())
        XCTAssertEqual(backup.defaultRoadmapType, "SQL")
        current = current.addingTimeInterval(86400); reopened.start()
        XCTAssertEqual(reopened.targetToday(at: current), 7200)
    }

    func testAnAccidentalTapLeavesNoBlock() throws {
        let container = try makeContainer()
        let store = try makeStore(container)
        store.start()
        current = current.addingTimeInterval(2)
        store.pause()
        XCTAssertTrue(store.log.segments.isEmpty)
        XCTAssertTrue(try makeStore(container).log.segments.isEmpty, "and nothing is saved")
    }

    func testTodaysTargetIsTheOneTheDayStartedWith() throws {
        let store = try makeStore(try makeContainer())
        XCTAssertEqual(store.targetToday(at: current), 6 * 3600, "Six hours by default")
        store.start()
        current = current.addingTimeInterval(600)
        store.pause()
        XCTAssertEqual(store.blocksToday(at: current).count, 1)
        XCTAssertEqual(store.days(at: current).first?.target, 6 * 3600)
    }

    func testBackupRestoresEverythingIntoAnotherPhone() throws {
        let original = try makeStore(try makeContainer())
        original.start()
        current = current.addingTimeInterval(3600)
        original.pause()
        current = current.addingTimeInterval(600)
        original.start()
        let data = try original.backupData()

        let other = try makeStore(try makeContainer())
        XCTAssertFalse(other.restoreBackup(data), "A backup cannot resume a timer without reconciling its end")
        XCTAssertTrue(other.log.segments.isEmpty)
        current = current.addingTimeInterval(600)
        XCTAssertTrue(other.restoreBackup(data, confirmedRunningEnd: current))
        XCTAssertEqual(other.log.segments.count, 2)
        XCTAssertFalse(other.isRunning, "The restored block closes at its confirmed actual end")
        XCTAssertEqual(other.settings, .standard)
    }

    func testADamagedBackupChangesNothing() throws {
        let store = try makeStore(try makeContainer())
        store.start()
        current = current.addingTimeInterval(600)
        store.pause()
        XCTAssertFalse(store.restoreBackup(Data("not a backup".utf8)))
        XCTAssertNotNil(store.message)
        XCTAssertEqual(store.log.segments.count, 1, "The current blocks stay")

        let overlapping = """
        {"version":1,"exportedAt":"2026-10-14T13:00:00Z","segments":[
         {"id":"\(UUID().uuidString)","start":"2026-10-14T09:00:00Z","end":"2026-10-14T10:00:00Z","source":"timer","dayTarget":21600},
         {"id":"\(UUID().uuidString)","start":"2026-10-14T09:30:00Z","end":"2026-10-14T11:00:00Z","source":"timer","dayTarget":21600}]}
        """
        XCTAssertThrowsError(try StudyLogStore.validatedBackup(Data(overlapping.utf8)))
        XCTAssertFalse(store.restoreBackup(Data(overlapping.utf8)), "Overlapping blocks are refused whole")
        XCTAssertEqual(store.log.segments.count, 1)
    }
}
