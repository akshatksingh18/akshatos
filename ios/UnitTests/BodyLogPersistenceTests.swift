import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

@MainActor private final class FakeBodyReminders: BodyReminding {
    var allowed = true
    var enabledWith: (weekday: Int, hour: Int)?
    var disabled = false

    func enable(weekday: Int, hour: Int, minute: Int) async throws -> Bool {
        enabledWith = (weekday, hour)
        return allowed
    }

    func disable() { disabled = true }
}

@MainActor final class BodyLogPersistenceTests: XCTestCase {
    private var sandbox: URL!
    private var defaults: UserDefaults!
    private var suite: String!
    private var clock = Date(timeIntervalSince1970: 1_789_819_200) // Saturday 2026-09-19 12:00 UTC
    private var calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!
        return value
    }()

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("body-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        suite = "body-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
        defaults.removePersistentDomain(forName: suite)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: BodyLogSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: BodyLogMigration.self,
                                  configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func makeStore(container: ModelContainer, photos name: String = "Photos",
                           reminders: FakeBodyReminders = FakeBodyReminders()) throws -> BodyLogStore {
        let store = BodyLogStore(repository: SwiftDataBodyLogRepository(container: container),
                                 photos: try BodyPhotoStorage(root: sandbox.appendingPathComponent(name)),
                                 reminders: reminders, defaults: defaults,
                                 now: { [unowned self] in self.clock }, calendar: calendar)
        store.load()
        return store
    }

    private func sampleImage() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 60)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        }.pngData()!
    }

    func testTodaysWeightIsReplacedNotDuplicatedAndSurvivesReopening() throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        store.logWeight(180.24)
        store.logWeight(179.8)
        XCTAssertEqual(store.weights.count, 1, "A second weigh-in the same day replaces the first")
        XCTAssertEqual(store.todayWeight?.pounds, 179.8)

        let reopened = try makeStore(container: container)
        XCTAssertEqual(reopened.weights.map(\.pounds), [179.8], "The weigh-in was saved, not just shown")
    }

    func testAnImpossibleWeightIsRefusedWithAMessage() throws {
        let store = try makeStore(container: try makeContainer())
        store.logWeight(20)
        XCTAssertTrue(store.weights.isEmpty)
        XCTAssertNotNil(store.message)
    }

    func testRollingAverageAndWeekChange() throws {
        let store = try makeStore(container: try makeContainer())
        store.logWeight(182)                                    // Sat 09-19, new block
        clock = clock.addingTimeInterval(6 * 86_400)
        store.logWeight(180)                                    // Fri 09-25, same block
        clock = clock.addingTimeInterval(86_400)
        store.logWeight(178)                                    // Sat 09-26, next block
        XCTAssertEqual(store.rollingAverage, 179, "The last seven days: 180 and 178")
        let week = try XCTUnwrap(store.weekChange)
        XCTAssertEqual(week.average, 178, "This block holds only today's weigh-in")
        XCTAssertEqual(week.change, -3, "Against the previous block's 181 average")
    }

    func testMeasurementSavesEditsDeletesAndShowsChange() throws {
        let container = try makeContainer()
        let store = try makeStore(container: container)
        XCTAssertTrue(store.saveMeasurement([.waistNavel: 35, .neck: 15.5, .chest: 40]))
        XCTAssertNotNil(store.thisWeekMeasurement, "Measured this week")

        clock = clock.addingTimeInterval(7 * 86_400)
        XCTAssertNil(store.thisWeekMeasurement, "A new week needs a new session")
        XCTAssertTrue(store.saveMeasurement([.waistNavel: 34.5]))
        let latest = try XCTUnwrap(store.latestMeasurement)
        XCTAssertEqual(store.change(for: .waistNavel, in: latest), -0.5)
        XCTAssertNil(store.change(for: .neck, in: latest), "A skipped site shows no change")

        XCTAssertTrue(store.saveMeasurement([.waistNavel: 34.25, .neck: 15.25], editing: latest))
        XCTAssertEqual(store.measurements.count, 2, "Editing updates the session in place")
        XCTAssertEqual(store.latestMeasurement?.id, latest.id)
        XCTAssertEqual(store.latestMeasurement?.value(.neck), 15.25)

        let reopened = try makeStore(container: container)
        XCTAssertEqual(reopened.measurements.map { $0.value(.waistNavel) }, [34.25, 35])
        reopened.deleteMeasurement(try XCTUnwrap(reopened.latestMeasurement))
        XCTAssertEqual(reopened.measurements.count, 1)
    }

    func testInvalidOrEmptyMeasurementsAreRefused() throws {
        let store = try makeStore(container: try makeContainer())
        XCTAssertFalse(store.saveMeasurement([:]))
        XCTAssertFalse(store.saveMeasurement([.waistNavel: 34, .neck: 2]))
        XCTAssertTrue(store.measurements.isEmpty, "Nothing is saved when any site is out of range")
    }

    func testEditingKeepsSitesAnotherBuildRecorded() throws {
        let container = try makeContainer()
        let repository = SwiftDataBodyLogRepository(container: container)
        let session = BodyMeasurement(day: "2026-09-19", recordedAt: clock,
                                      inches: ["waistNavel": 35, "forearmRight": 12])
        try repository.save(session)
        let store = try makeStore(container: container)
        XCTAssertTrue(store.saveMeasurement([.waistNavel: 34.75], editing: session))
        XCTAssertEqual(store.latestMeasurement?.inches["forearmRight"], 12,
                       "A site this build does not know about survives an edit")
    }

    func testEstimatesNeedHeightWaistAndNeck() throws {
        let store = try makeStore(container: try makeContainer())
        store.saveMeasurement([.waistNavel: 36, .neck: 16])
        XCTAssertNil(store.bodyFatEstimate, "No height, no estimate")
        store.heightInches = 70
        XCTAssertEqual(try XCTUnwrap(store.bodyFatEstimate), 19.43, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(store.waistToHeight), 36.0 / 70, accuracy: 0.0001)

        let reopened = try makeStore(container: try makeContainer())
        XCTAssertEqual(reopened.heightInches, 70, "Height is remembered on this phone")
    }

    func testPhotoIsStoredAsJpegAndDeletedWithItsFile() async throws {
        let store = try makeStore(container: try makeContainer())
        XCTAssertTrue(store.photosDue)
        await store.addPhoto(sampleImage(), pose: .side)
        let photo = try XCTUnwrap(store.photoRecords.first)
        XCTAssertEqual(photo.pose, .side)
        let url = try XCTUnwrap(store.photoURL(photo))
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8], "Stored as a JPEG")
        XCTAssertFalse(store.photosDue, "A photo today means the next ones are two weeks away")

        store.deletePhoto(photo)
        XCTAssertTrue(store.photoRecords.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "Deleting removes the file too")
    }

    func testUnreadableImageIsRefused() async throws {
        let store = try makeStore(container: try makeContainer())
        await store.addPhoto(Data("not an image".utf8), pose: .front)
        XCTAssertTrue(store.photoRecords.isEmpty)
        XCTAssertNotNil(store.message)
    }

    func testBackupFolderRestoresEverythingIncludingPhotos() async throws {
        let source = try makeStore(container: try makeContainer(), photos: "SourcePhotos")
        source.logWeight(181.5)
        source.saveMeasurement([.waistNavel: 34.5, .hips: 39])
        await source.addPhoto(sampleImage(), pose: .front)
        let folder = try source.stageBackup()

        let target = try makeStore(container: try makeContainer(), photos: "TargetPhotos")
        target.logWeight(200)
        target.restore(from: folder)

        XCTAssertEqual(target.snapshot, source.snapshot, "Every record comes back exactly")
        let photo = try XCTUnwrap(target.photoRecords.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(target.photoURL(photo)).path),
                      "The photo file is restored beside its record")
        XCTAssertEqual(target.message, "Restored.")
    }

    func testAnInvalidBackupChangesNothing() async throws {
        let store = try makeStore(container: try makeContainer())
        store.logWeight(180)
        await store.addPhoto(sampleImage(), pose: .front)
        let before = store.snapshot
        let bad = sandbox.appendingPathComponent("bad.json")
        try Data("{\"version\": 99}".utf8).write(to: bad)

        store.restore(from: bad)

        XCTAssertEqual(store.snapshot, before, "A rejected backup leaves every record")
        let photo = try XCTUnwrap(store.photoRecords.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(store.photoURL(photo)).path),
                      "and every photo in place")
        XCTAssertNotNil(store.message)
    }

    func testReminderFollowsPermissionAndMeasurementDay() async throws {
        let reminders = FakeBodyReminders()
        let store = try makeStore(container: try makeContainer(), reminders: reminders)
        await store.setReminder(enabled: true)
        XCTAssertTrue(store.reminderEnabled)
        XCTAssertEqual(reminders.enabledWith?.weekday, 7, "Saturday by default")
        XCTAssertEqual(reminders.enabledWith?.hour, 8)

        await store.setReminder(enabled: false)
        XCTAssertFalse(store.reminderEnabled)
        XCTAssertTrue(reminders.disabled)

        reminders.allowed = false
        await store.setReminder(enabled: true)
        XCTAssertFalse(store.reminderEnabled, "Without notification permission the reminder is off")
        XCTAssertNotNil(store.message, "and the screen says why")
    }

    func testCSVHasOneRowPerDay() throws {
        let store = try makeStore(container: try makeContainer())
        store.logWeight(181)
        store.saveMeasurement([.waistNavel: 34.5])
        let text = String(decoding: store.csvData(), as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("date,weight_lb,waist_navel_in,"))
        XCTAssertTrue(text.contains("\n2026-09-19,181,34.5,"))
    }
}
