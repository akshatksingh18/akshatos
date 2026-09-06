import Foundation
import SwiftData

@MainActor protocol SquatRepository {
    func load() throws -> [SquatSession]
    func save(_ session: SquatSession) throws
    func replaceAll(with sessions: [SquatSession]) throws
    func delete(ids: Set<UUID>) throws
}

@MainActor final class SwiftDataSquatRepository: SquatRepository {
    private var container: ModelContainer?

    init(container: ModelContainer? = nil) { self.container = container }

    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: SquatSchemaV1.self)
            container = try ModelContainer(for: schema, migrationPlan: SquatMigration.self,
                configurations: [ModelConfiguration("Squats", schema: schema)])
        }
        return container!.mainContext
    }

    func load() throws -> [SquatSession] {
        let rows = try context().fetch(FetchDescriptor<SquatSchemaV1.SavedSession>())
        let sessions = try rows.map { try JSONDecoder().decode(SquatSession.self, from: $0.payload) }
        guard sessions.filter({ $0.isActive }).count <= 1,
              Set(sessions.map(\.id)).count == sessions.count,
              zip(rows, sessions).allSatisfy({ $0.0.id == $0.1.id }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return sessions.sorted { $0.started > $1.started }
    }

    func save(_ session: SquatSession) throws {
        let context = try context()
        do {
            let payload = try JSONEncoder().encode(session)
            let rows = try context.fetch(FetchDescriptor<SquatSchemaV1.SavedSession>())
            if let row = rows.first(where: { $0.id == session.id }) { row.payload = payload }
            else { context.insert(try SquatSchemaV1.SavedSession(session)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func replaceAll(with sessions: [SquatSession]) throws {
        guard Set(sessions.map(\.id)).count == sessions.count,
              sessions.filter(\.isActive).count <= 1 else { throw CocoaError(.fileReadCorruptFile) }
        let context = try context()
        do {
            let rows = try context.fetch(FetchDescriptor<SquatSchemaV1.SavedSession>())
            let replacements = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
            for row in rows {
                if let session = replacements[row.id] { row.payload = try JSONEncoder().encode(session) }
                else { context.delete(row) }
            }
            let existing = Set(rows.map(\.id))
            for session in sessions where !existing.contains(session.id) {
                context.insert(try SquatSchemaV1.SavedSession(session))
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<SquatSchemaV1.SavedSession>()) where ids.contains(row.id) {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
