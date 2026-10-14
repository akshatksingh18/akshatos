import Foundation
import SwiftData

@MainActor protocol StudyLogRepository {
    func load() throws -> [StudySegment]
    func save(_ segment: StudySegment) throws
    func delete(id: UUID) throws
    func replaceAll(with segments: [StudySegment]) throws
}

@MainActor final class SwiftDataStudyLogRepository: StudyLogRepository {
    private var container: ModelContainer?

    init(container: ModelContainer? = nil) { self.container = container }

    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: StudyLogSchemaV1.self)
            container = try ModelContainer(for: schema, migrationPlan: StudyLogMigration.self,
                configurations: [ModelConfiguration("StudyLog", schema: schema)])
        }
        return container!.mainContext
    }

    func load() throws -> [StudySegment] {
        let rows = try context().fetch(FetchDescriptor<StudyLogSchemaV1.SavedSegment>())
        let segments = try rows.map { try JSONDecoder().decode(StudySegment.self, from: $0.payload) }
        guard zip(rows, segments).allSatisfy({ $0.0.id == $0.1.id }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return try StudyLog.validated(segments)
    }

    func save(_ segment: StudySegment) throws {
        let context = try context()
        do {
            let rows = try context.fetch(FetchDescriptor<StudyLogSchemaV1.SavedSegment>())
            let payload = try JSONEncoder().encode(segment)
            if let row = rows.first(where: { $0.id == segment.id }) { row.payload = payload }
            else { context.insert(try StudyLogSchemaV1.SavedSegment(segment)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<StudyLogSchemaV1.SavedSegment>()) where row.id == id {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func replaceAll(with segments: [StudySegment]) throws {
        let checked = try StudyLog.validated(segments)
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<StudyLogSchemaV1.SavedSegment>()) {
                context.delete(row)
            }
            for segment in checked { context.insert(try StudyLogSchemaV1.SavedSegment(segment)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
