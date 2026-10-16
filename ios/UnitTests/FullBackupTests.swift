import SwiftData
import UIKit
import XCTest
@testable import AkshatOS

@MainActor private final class QuietReminders: SquatReminders {
    func authorize() async throws -> Bool { true }
    func snapshot() async -> ReminderSnapshot { ReminderSnapshot(allowed: true, authorization: .authorized) }
    func schedule(_ session: SquatSession, firstReminderAt: Date) async throws {}
    func ensureDailyStartReminder() async throws {}
    func cancel() {}
    func cancelDailyStartReminder() {}
}

@MainActor private final class EmptyActionInbox: SquatActionInbox {
    func pending() throws -> [SquatAction] { [] }
    func enqueue(_ action: SquatAction) throws {}
    func remove(_ id: String) throws {}
}

@MainActor private final class NoHome: HomeAutomationPersistence {
    func load() throws -> HomeAutomationState? { nil }
    func save(_ state: HomeAutomationState) throws {}
    func delete() throws {}
}

@MainActor private final class NoHomeEvents: HomeEventInbox {
    func pending() throws -> [HomeBoundaryEvent] { [] }
    func enqueue(_ event: HomeBoundaryEvent) throws {}
    func remove(_ id: String) throws {}
}

@MainActor private final class SilentBodyReminders: BodyReminding {
    func enable(weekday: Int, hour: Int, minute: Int) async throws -> Bool { true }
    func disable() {}
}

/// The whole-hub backup against real stores and real files: every module is written into one
/// folder by one phone and restored into a second phone that never saw any of it.
@MainActor final class FullBackupTests: XCTestCase {
    private struct Phone {
        let squats: SquatStore
        let pageVault: PageVaultStore
        let liftLog: LiftLogStore
        let body: BodyLogStore
        let studyLog: StudyLogStore
        let todo: TodoStore
        let journal: JournalStore
        let watchlist: WatchlistStore
        let spending: SpendingStore
        let backup: FullBackupService
    }

    private var sandbox: URL!
    private var suites: [String] = []
    private let clock = Date(timeIntervalSince1970: 1_789_819_200) // 2026-09-19 12:00 UTC
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC")!
        return value
    }()

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("full-backup-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
        for suite in suites { UserDefaults().removePersistentDomain(forName: suite) }
    }

    private func container<Version: VersionedSchema, Plan: SchemaMigrationPlan>(
        _ version: Version.Type, _ plan: Plan.Type, name: String) throws -> ModelContainer {
        let schema = Schema(versionedSchema: version)
        return try ModelContainer(for: schema, migrationPlan: plan,
                                  configurations: [ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: true)])
    }

    private func makePhone(_ name: String, squatSessions: [SquatSession] = []) async throws -> Phone {
        let root = sandbox.appendingPathComponent(name, isDirectory: true)
        let suite = "full-backup-tests-\(name)-\(UUID().uuidString)"
        suites.append(suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let clock = self.clock

        let squatRepository = SwiftDataSquatRepository(
            container: try container(SquatSchemaV1.self, SquatMigration.self, name: "\(name)-squats"))
        try squatRepository.replaceAll(with: squatSessions)
        let squats = SquatStore(defaults: defaults, repository: squatRepository, reminders: QuietReminders(),
                                inbox: EmptyActionInbox(), homePersistence: NoHome(), homeInbox: NoHomeEvents(),
                                homeMonitor: InactiveHomeRegionMonitor(), now: { clock }, calendar: calendar)
        let pageVault = PageVaultStore(
            repository: SwiftDataPageVaultRepository(
                container: try container(PageVaultSchemaV1.self, PageVaultMigration.self, name: "\(name)-pagevault")),
            storage: try PageVaultStorage(root: root.appendingPathComponent("PageVault")),
            documents: PageVaultDocumentService(), now: { clock })
        await pageVault.load()
        let liftLog = LiftLogStore(
            repository: SwiftDataLiftLogRepository(
                container: try container(LiftLogSchemaV1.self, LiftLogMigration.self, name: "\(name)-liftlog")),
            splits: DefaultsLiftSplitStorage(defaults: defaults), now: { clock })
        liftLog.load()
        let body = BodyLogStore(
            repository: SwiftDataBodyLogRepository(
                container: try container(BodyLogSchemaV1.self, BodyLogMigration.self, name: "\(name)-body")),
            photos: try BodyPhotoStorage(root: root.appendingPathComponent("Photos")),
            reminders: SilentBodyReminders(), defaults: defaults, now: { clock }, calendar: calendar)
        body.load()
        let studyLog = StudyLogStore(
            repository: SwiftDataStudyLogRepository(
                container: try container(StudyLogSchemaV1.self, StudyLogMigration.self, name: "\(name)-studylog")),
            defaults: defaults, now: { clock }, calendar: calendar)
        studyLog.load()
        func snapshot(_ version: any VersionedSchema.Type) throws -> ModelContainer {
            let schema = Schema(versionedSchema: version)
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        }
        defaults.set(false, forKey: "journal.lock-enabled")
        let todo = TodoStore(container: try snapshot(TodoSchemaV1.self), now: { clock }, calendar: calendar); todo.load()
        let journal = JournalStore(container: try snapshot(JournalSchemaV1.self), defaults: defaults, photoFolder: root.appendingPathComponent("JournalPhotos")); journal.load()
        let watchlist = WatchlistStore(container: try snapshot(WatchlistSchemaV1.self)); watchlist.load()
        let spending = SpendingStore(container: try snapshot(SpendingSchemaV1.self)); spending.load()
        let preferences = PersonalPreferences(defaults: defaults)
        let backup = FullBackupService(parts: [squats, pageVault, liftLog, body, studyLog, todo, journal, watchlist, spending, preferences],
                                       now: { clock }, calendar: calendar, appVersion: "test",
                                       scratch: root.appendingPathComponent("Outgoing"))
        return Phone(squats: squats, pageVault: pageVault, liftLog: liftLog, body: body, studyLog: studyLog, todo: todo, journal: journal, watchlist: watchlist, spending: spending,
                     backup: backup)
    }

    private func finishedDay(sets: Int) -> SquatSession {
        var session = SquatSession(day: SquatSession.dayKey(clock.addingTimeInterval(-86_400), calendar: calendar),
                                   started: clock.addingTimeInterval(-86_400), interval: 45, goal: 8, state: .running)
        // Sets are logged while the day is running; an ended day ignores new ones.
        for index in 0..<sets {
            session.log(SquatEvent(date: session.started.addingTimeInterval(Double(index + 1) * 2700), kind: .done))
        }
        session.state = .ended
        session.ended = session.started.addingTimeInterval(8 * 3600)
        precondition(session.count == sets, "The fixture holds the sets it was given")
        return session
    }

    private func makePDF(pages: Int, title: String) throws -> URL {
        let url = sandbox.appendingPathComponent("\(title).pdf")
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 400, height: 600))
        try renderer.writePDF(to: url) { context in
            for index in 0..<pages {
                context.beginPage()
                ("\(title) page \(index + 1)" as NSString).draw(at: CGPoint(x: 24, y: 24), withAttributes: nil)
            }
        }
        return url
    }

    private func sampleImage() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 60)).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        }.pngData()!
    }

    /// Fills every module on one phone and returns it.
    private func filledPhone() async throws -> Phone {
        let phone = try await makePhone("PhoneA", squatSessions: [finishedDay(sets: 6)])
        phone.liftLog.startWorkout(split: phone.liftLog.splits.first)
        let exercise = try XCTUnwrap(phone.liftLog.active?.exercises.first)
        phone.liftLog.addSet(exerciseID: exercise.id, reps: 8, load: 45)
        phone.body.logWeight(182.4)
        phone.body.heightInches = 70
        await phone.body.addPhoto(sampleImage(), pose: .front)
        await phone.pageVault.importBook(from: try makePDF(pages: 12, title: "Alpha"))
        let alpha = try XCTUnwrap(phone.pageVault.books.first)
        phone.pageVault.setPlace(alpha, page: 5)
        XCTAssertTrue(phone.studyLog.saveSegment(StudySegment(start: clock.addingTimeInterval(-600), end: clock, source: .manual, dayTarget: 21600)))
        XCTAssertTrue(phone.todo.add("Synthetic priority"))
        phone.todo.choose(try XCTUnwrap(phone.todo.visible.first?.id), day: phone.todo.today)
        var entry = phone.journal.newEntry(phone.journal.today); entry.text = "Synthetic reflection"
        XCTAssertTrue(phone.journal.save(entry)); phone.journal.markDone(entry)
        phone.journal.addPhoto(sampleImage(), day: entry.day)
        phone.watchlist.add(title: "Synthetic film", mood: "Calm", kind: "Movie")
        phone.watchlist.mark(try XCTUnwrap(phone.watchlist.state.titles.first?.id), watched: true)
        XCTAssertTrue(phone.spending.add(title: "Synthetic expense", amount: "12.34", category: "Other", date: clock))
        XCTAssertNil(phone.liftLog.message)
        XCTAssertNil(phone.body.message)
        XCTAssertNil(phone.pageVault.message)
        return phone
    }

    func testEverythingRestoresIntoAFreshPhone() async throws {
        let original = try await filledPhone()
        let folder = try await original.backup.prepareExport()

        XCTAssertTrue(folder.lastPathComponent.hasPrefix("AkshatOS Backup 2026-09-19"))
        let manifest = try AkshatOSBackupManifest.decode(
            Data(contentsOf: folder.appendingPathComponent(AkshatOSBackupManifest.fileName)))
        XCTAssertEqual(manifest.parts.map(\.id), ["pushups", "pageVault", "liftLog", "body", "studyLog", "todo", "journal", "watchlist", "spending", "personal-settings"])
        XCTAssertEqual(manifest.parts.map(\.path), ["pushups.json", "pagevault", "lift-log.json", "body",
                                                    "study-log.json", "todo.json", "journal", "watchlist.json", "spending.json", "personal-settings.json"])
        for part in manifest.parts {
            XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(part.path).path),
                          "\(part.title) is in the folder")
        }

        let fresh = try await makePhone("PhoneB")
        let prepared = try await fresh.backup.prepareRestore(from: folder)
        XCTAssertEqual(prepared.titles, ["Pushups", "PageVault", "Lift Log", "Body", "Study Log", "To-do", "Journal", "Watchlist", "Spending", "Personal settings"])
        let summary = await fresh.backup.restore(prepared)
        XCTAssertTrue(summary.hasPrefix("Restored: Pushups, PageVault, Lift Log, Body, Study Log, To-do, Journal, Watchlist, Spending, Personal settings."), summary)
        XCTAssertFalse(summary.contains("Not restored"), summary)
        XCTAssertTrue(summary.contains("resume any open day"), "A module's note follows the summary")
        XCTAssertNil(fresh.squats.notice, "The summary replaces the module's own alert")

        XCTAssertEqual(fresh.squats.sessions.map(\.count), [6], "Pushup history comes back")
        XCTAssertEqual(fresh.liftLog.totalSetCount, 1, "Lift Log comes back")
        XCTAssertEqual(fresh.liftLog.active?.exercises.first?.sets.first?.load, 45)
        XCTAssertEqual(fresh.body.weights.map(\.pounds), [182.4], "Body weigh-ins come back")
        XCTAssertEqual(fresh.body.snapshot.photos.count, 1, "Body photos come back")
        XCTAssertEqual(fresh.body.heightInches, 70, "Height comes back with Body")
        XCTAssertEqual(fresh.pageVault.books.map(\.title), ["Alpha"], "PageVault books come back with their PDF")
        XCTAssertEqual(fresh.pageVault.books.first?.openingPage, 5)
        XCTAssertFalse(fresh.studyLog.isRunning)
        XCTAssertEqual(fresh.todo.visible.map(\.title), ["Synthetic priority"])
        XCTAssertEqual(fresh.journal.entries.first?.text, "Synthetic reflection")
        XCTAssertNotNil(fresh.journal.photo(try XCTUnwrap(fresh.journal.entries.first?.photos.first)))
        XCTAssertTrue(fresh.watchlist.state.watched(try XCTUnwrap(fresh.watchlist.state.titles.first?.id)))
        XCTAssertEqual(fresh.spending.state.expenses.first?.cents, 1234)
        XCTAssertEqual(fresh.studyLog.log.segments.count, 1)
        XCTAssertNil(fresh.studyLog.message, "The hub's summary replaces Study Log's own restore message")
        XCTAssertNil(fresh.body.message, "The hub's summary replaces each module's own restore message")

        original.backup.finishExport()
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path), "Finishing clears what was staged")
    }

    func testOneDamagedPartRestoresNothing() async throws {
        let original = try await filledPhone()
        let folder = try await original.backup.prepareExport()
        try Data("not a backup".utf8).write(
            to: folder.appendingPathComponent("lift-log.json"), options: .atomic)

        let other = try await makePhone("PhoneB")
        other.body.logWeight(150)
        do {
            _ = try await other.backup.prepareRestore(from: folder)
            XCTFail("A damaged part must stop the restore")
        } catch let error as AkshatOSBackupError {
            guard case .invalidPart(let title, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(title, "Lift Log")
        }
        XCTAssertEqual(other.body.weights.map(\.pounds), [150], "Nothing on the phone changed")
        XCTAssertTrue(other.squats.sessions.isEmpty)
    }

    func testAFolderThatIsNotABackupOrIsNewerIsRefused() async throws {
        let phone = try await makePhone("PhoneA")
        let plain = sandbox.appendingPathComponent("Some folder", isDirectory: true)
        try FileManager.default.createDirectory(at: plain, withIntermediateDirectories: true)
        do {
            _ = try await phone.backup.prepareRestore(from: plain)
            XCTFail("A folder without the index is not a backup")
        } catch let error as AkshatOSBackupError {
            XCTAssertEqual(error, .notABackup)
        }

        let newer = #"{"format":"akshatos-full-backup","version":99,"parts":["pushups"]}"#
        try Data(newer.utf8).write(to: plain.appendingPathComponent(AkshatOSBackupManifest.fileName))
        do {
            _ = try await phone.backup.prepareRestore(from: plain)
            XCTFail("A newer backup is refused")
        } catch let error as AkshatOSBackupError {
            XCTAssertEqual(error, .newerVersion)
        }
    }

    func testAnEmptyLibraryIsLeftOutAndAMissingPartIsNamed() async throws {
        let phone = try await makePhone("PhoneA", squatSessions: [finishedDay(sets: 2)])
        let folder = try await phone.backup.prepareExport()
        let manifest = try AkshatOSBackupManifest.decode(
            Data(contentsOf: folder.appendingPathComponent(AkshatOSBackupManifest.fileName)))
        XCTAssertEqual(manifest.parts.map(\.id), ["pushups", "liftLog", "body", "studyLog", "todo", "watchlist", "spending", "personal-settings"],
                       "An empty PageVault has nothing to export")

        try FileManager.default.removeItem(at: folder.appendingPathComponent("body"))
        do {
            _ = try await phone.backup.prepareRestore(from: folder)
            XCTFail("A listed part that is gone must be reported")
        } catch let error as AkshatOSBackupError {
            XCTAssertEqual(error, .missingPart("Body"))
        }
    }

    /// A backup from a build with a module this one lacks must not restore half of itself.
    func testAPartFromAModuleThisBuildLacksIsRefused() async throws {
        let phone = try await makePhone("PhoneA", squatSessions: [finishedDay(sets: 2)])
        let folder = try await phone.backup.prepareExport()
        let indexURL = folder.appendingPathComponent(AkshatOSBackupManifest.fileName)
        var manifest = try AkshatOSBackupManifest.decode(Data(contentsOf: indexURL))
        try Data("{}".utf8).write(to: folder.appendingPathComponent("reels.json"))
        manifest.parts.append(.init(id: "reelVault", title: "ReelVault", path: "reels.json"))
        try manifest.encoded().write(to: indexURL)
        do {
            _ = try await phone.backup.prepareRestore(from: folder)
            XCTFail("An unknown part must stop the restore")
        } catch let error as AkshatOSBackupError {
            XCTAssertEqual(error, .unknownPart("ReelVault"))
        }
    }

    /// ReelVault was removed after Build 32: its videos and records are deleted on launch, and
    /// nothing else in Application Support is touched.
    func testRemovedReelVaultLeavesNothingBehind() throws {
        let support = sandbox.appendingPathComponent("Support", isDirectory: true)
        let media = support.appendingPathComponent("ReelVault/Media", isDirectory: true)
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try Data("video".utf8).write(to: media.appendingPathComponent("clip.mp4"))
        for name in ["ReelVault.store", "ReelVault.store-wal", "LiftLog.store", "PageVault"] {
            try Data("x".utf8).write(to: support.appendingPathComponent(name))
        }
        XCTAssertEqual(Set(RetiredModuleCleanup.run(in: support)), ["ReelVault", "ReelVault.store", "ReelVault.store-wal"])
        let left = try FileManager.default.contentsOfDirectory(atPath: support.path)
        XCTAssertEqual(Set(left), ["LiftLog.store", "PageVault"], "Other modules' data stays")
        XCTAssertEqual(RetiredModuleCleanup.run(in: support), [], "Once clean, it does nothing")
    }

    func testModuleIdsMustBeUniqueAndPartNamesPlain() throws {
        XCTAssertNoThrow(try AkshatOSBackupManifest.checkRegistry(["pushups", "body"]))
        XCTAssertThrowsError(try AkshatOSBackupManifest.checkRegistry(["body", "body"]))
        XCTAssertThrowsError(try AkshatOSBackupManifest.checkRegistry([""]))
        XCTAssertTrue(AkshatOSBackupManifest.isPlainName("lift-log.json"))
        for unsafe in ["../x", "a/b", ".hidden", "", AkshatOSBackupManifest.fileName] {
            XCTAssertFalse(AkshatOSBackupManifest.isPlainName(unsafe), unsafe)
        }
    }
}
