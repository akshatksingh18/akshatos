import XCTest
import SwiftData
@testable import AkshatOS

@MainActor final class SquatsPersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SquatSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: SquatMigration.self,
                                  configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }

    private func session() -> SquatSession {
        SquatSession(day: "2026-09-03", started: Date(timeIntervalSince1970: 1_788_480_000),
                     interval: 45, goal: 3)
    }

    func testSessionRoundTripAcrossContexts() throws {
        let container = try makeContainer()
        var original = session()
        original.log(SquatEvent(date: original.started, kind: .done))
        let writer = ModelContext(container)
        writer.insert(try SquatSchemaV1.SavedSession(original))
        try writer.save()
        let reader = ModelContext(container)
        let rows = try reader.fetch(FetchDescriptor<SquatSchemaV1.SavedSession>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(try JSONDecoder().decode(SquatSession.self, from: XCTUnwrap(rows.first).payload), original)
    }

    func testUndoAndEndPersistWithoutLosingIdentity() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        var original = session()
        original.log(SquatEvent(date: original.started, kind: .done))
        let row = try SquatSchemaV1.SavedSession(original)
        context.insert(row)
        try context.save()
        original.undo()
        original.state = .ended
        original.ended = original.started.addingTimeInterval(3600)
        row.payload = try JSONEncoder().encode(original)
        try context.save()
        let reader = ModelContext(container)
        let saved = try XCTUnwrap(reader.fetch(FetchDescriptor<SquatSchemaV1.SavedSession>()).first)
        let restored = try JSONDecoder().decode(SquatSession.self, from: saved.payload)
        XCTAssertEqual(saved.id, original.id)
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.count, 0)
        XCTAssertFalse(restored.isActive)
    }

    func testMalformedPayloadThrowsWithoutDeletingRow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let row = try SquatSchemaV1.SavedSession(session())
        row.payload = Data("not valid JSON".utf8)
        context.insert(row)
        try context.save()
        XCTAssertThrowsError(try JSONDecoder().decode(SquatSession.self, from: row.payload))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SquatSchemaV1.SavedSession>()), 1)
    }

    func testRepositoryReplaceAndDeletePersistAcrossContexts() throws {
        let container = try makeContainer()
        let repository = SwiftDataSquatRepository(container: container)
        let original = session()
        try repository.save(original)
        var replacement = session()
        replacement.id = UUID()
        replacement.state = .ended
        replacement.ended = replacement.started.addingTimeInterval(1800)
        try repository.replaceAll(with: [replacement])
        XCTAssertEqual(try repository.load(), [replacement])
        try repository.delete(ids: [replacement.id])
        XCTAssertTrue(try repository.load().isEmpty)
    }

    func testRepositoryRejectsInvalidReplacementWithoutChangingData() throws {
        let container = try makeContainer()
        let repository = SwiftDataSquatRepository(container: container)
        let original = session()
        try repository.save(original)
        var duplicate = original
        duplicate.started = original.started.addingTimeInterval(1)
        XCTAssertThrowsError(try repository.replaceAll(with: [original, duplicate]))
        XCTAssertEqual(try repository.load(), [original])
    }
}
