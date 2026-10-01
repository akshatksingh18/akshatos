import Foundation
import SwiftData

@MainActor protocol ReelVaultRepository {
    func load() throws -> [ReelVideo]
    func save(_ video: ReelVideo) throws
    func delete(id: UUID) throws
}

@MainActor final class SwiftDataReelVaultRepository: ReelVaultRepository {
    private var container: ModelContainer?

    init(container: ModelContainer? = nil) { self.container = container }

    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: ReelVaultSchemaV1.self)
            container = try ModelContainer(for: schema, migrationPlan: ReelVaultMigration.self,
                configurations: [ModelConfiguration("ReelVault", schema: schema)])
        }
        return container!.mainContext
    }

    func load() throws -> [ReelVideo] {
        let rows = try context().fetch(FetchDescriptor<ReelVaultSchemaV1.SavedVideo>())
        let videos = try rows.map { try JSONDecoder().decode(ReelVideo.self, from: $0.payload) }
        guard zip(rows, videos).allSatisfy({ $0.0.id == $0.1.id }),
              (try? ReelVault.validated(videos)) != nil else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return videos
    }

    func save(_ video: ReelVideo) throws {
        let context = try context()
        do {
            let payload = try JSONEncoder().encode(video)
            let rows = try context.fetch(FetchDescriptor<ReelVaultSchemaV1.SavedVideo>())
            if let row = rows.first(where: { $0.id == video.id }) { row.payload = payload }
            else { context.insert(try ReelVaultSchemaV1.SavedVideo(video)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<ReelVaultSchemaV1.SavedVideo>()) where row.id == id {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
