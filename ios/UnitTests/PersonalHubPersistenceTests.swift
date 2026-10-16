import XCTest
import SwiftData
import UIKit
@testable import AkshatOS

@MainActor final class PersonalHubPersistenceTests: XCTestCase {
    private func container(_ type: any VersionedSchema.Type) throws -> ModelContainer {
        let schema = Schema(versionedSchema: type)
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }
    func testCompletionRepeatAndUndoSurviveRelaunch() throws {
        let db = try container(TodoSchemaV1.self)
        let store = TodoStore(container: db); store.load()
        XCTAssertTrue(store.add("Synthetic recurring task"))
        var item = try XCTUnwrap(store.visible.first); item.repeatRule = "daily"; store.save(item)
        store.choose(item.id, day: store.today); store.toggle(item.id)
        XCTAssertEqual(store.state.tasks.count, 2)
        XCTAssertEqual(store.plan(store.today)?.qualifies, true)
        let other = TodoStore(container: db); other.load()
        XCTAssertEqual(other.state.tasks.count, 2)
        store.load() // A foreground reload within the Undo window must preserve the inverse.
        store.undo()
        XCTAssertEqual(store.state.tasks.count, 1)
        XCTAssertNil(store.state.tasks.first?.completedAt)
        XCTAssertEqual(store.plan(store.today)?.qualifies, false)
        XCTAssertTrue(store.park("A synthetic thought"))
        let reopened = TodoStore(container: db); reopened.load()
        XCTAssertEqual(reopened.state.thoughts.count, 1)
    }
    func testUnavailableStoreCannotOverwriteExistingDataFromAnEmptyCache() throws {
        let db = try container(TodoSchemaV1.self)
        let store = TodoStore(container: db); store.load(); XCTAssertTrue(store.add("Keep me"))
        let unopened = TodoStore(container: db)
        XCTAssertFalse(unopened.add("Overwrite"))
        unopened.load()
        XCTAssertEqual(unopened.visible.map(\.title), ["Keep me"])
    }
    func testJournalLockHidesTextAndPhotosButAllowsCompletionFact() throws {
        let suite = "journal-test-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: "journal.lock-enabled")
        let db = try container(JournalSchemaV1.self)
        let store = JournalStore(container: db, defaults: defaults); store.load()
        var entry = store.newEntry(store.today); entry.text = "Synthetic private text"
        XCTAssertTrue(store.save(entry)); store.markDone(entry)
        defaults.set(true, forKey: "journal.lock-enabled")
        let locked = JournalStore(container: db, defaults: defaults); locked.load()
        XCTAssertTrue(locked.entries.isEmpty)
        XCTAssertNil(locked.entry(store.today))
        XCTAssertEqual(locked.daySummary(store.today, at: Date()).qualifies, true)
        XCTAssertFalse(locked.save(entry))
    }
    func testJournalRestoreStagesPhotosBeforeProviderAccessEnds() async throws {
        let suite = "journal-media-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defaults.set(false, forKey: "journal.lock-enabled")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: root) }
        let source = JournalStore(container: try container(JournalSchemaV1.self), defaults: defaults, photoFolder: root.appendingPathComponent("source")); source.load()
        var entry = source.newEntry(source.today); entry.text = "Synthetic photo entry"; XCTAssertTrue(source.save(entry))
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { UIColor.blue.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 4, height: 4)) }
        source.addPhoto(try XCTUnwrap(image.jpegData(compressionQuality: 0.8)), day: source.today)
        let backup = root.appendingPathComponent("backup"); try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        _ = try await source.writeBackup(into: backup)
        let target = JournalStore(container: try container(JournalSchemaV1.self), defaults: defaults, photoFolder: root.appendingPathComponent("target")); target.load()
        let restore = try await target.prepareBackupRestore(from: backup.appendingPathComponent("journal"))
        try FileManager.default.removeItem(at: backup)
        let outcome = await restore.apply()
        XCTAssertEqual(outcome, .restored)
        let photo = try XCTUnwrap(target.entry(target.today)?.photos.first)
        XCTAssertNotNil(target.photo(photo), "Restore must use validated local bytes after the provider disappears")
    }
    func testWatchlistMetadataImportKeepsPhoneWatchedEvents() throws {
        let db = try container(WatchlistSchemaV1.self)
        let store = WatchlistStore(container: db); store.load()
        let title = WatchTitle(title: "Synthetic")
        let transfer = WatchlistTransfer(sourceID: UUID(), revision: 1, titles: [title])
        store.preview(try LocalDataCoding.encode(transfer)); store.applyImport(); store.mark(title.id, watched: true)
        let reopened = WatchlistStore(container: db); reopened.load()
        XCTAssertTrue(reopened.state.watched(title.id))
        reopened.preview(try LocalDataCoding.encode(transfer))
        XCTAssertNil(reopened.pendingImport)
        XCTAssertTrue(reopened.state.watched(title.id))
    }
    func testBodyReminderCannotReactivateAfterFitnessHandover() async throws {
        let suite = "fitness-handover-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite)); defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = PersonalPreferences(defaults: defaults); preferences.fitnessStopped = true
        let allowed = try await GatedBodyReminders(preferences: preferences).enable(weekday: 2, hour: 8, minute: 0)
        XCTAssertFalse(allowed, "A later restore or lifecycle refresh cannot reacquire fitness reminder ownership")
    }
    func testStaleStudyNotificationCannotPauseAnotherBlock() throws {
        let suite = "stale-study-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let db = try container(StudyLogSchemaV1.self)
        let study = StudyLogStore(repository: SwiftDataStudyLogRepository(container: db), defaults: defaults)
        study.load(); study.start()
        let todo = TodoStore(container: try container(TodoSchemaV1.self)); todo.load()
        let scheduler = PersonalNotifications(study: study, todo: todo, preferences: PersonalPreferences(defaults: defaults))
        scheduler.respond(PersonalNotifications.pauseAction, blockID: UUID())
        XCTAssertTrue(study.isRunning, "A tap on an older delivered reminder cannot stop a newer block")
        scheduler.respond(PersonalNotifications.pauseAction, blockID: study.log.running?.id)
        XCTAssertFalse(study.isRunning)
    }
    func testInvalidSpendingRestoreCannotReplaceSavedExpenses() async throws {
        let db = try container(SpendingSchemaV1.self)
        let store = SpendingStore(container: db); store.load()
        var state = SpendingState(expenses: [Expense(title: "Synthetic", cents: 1234, currency: "USD", date: Date())])
        XCTAssertTrue(store.commit(state))
        state.expenses[0].cents = -1
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try LocalDataCoding.encode(state).write(to: url)
        do { _ = try await store.prepareBackupRestore(from: url); XCTFail("Invalid amount accepted") } catch {}
        let reopened = SpendingStore(container: db); reopened.load()
        XCTAssertEqual(reopened.state.expenses.first?.cents, 1234)
    }
}
