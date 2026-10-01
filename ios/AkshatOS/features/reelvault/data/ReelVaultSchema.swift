import Foundation
import SwiftData

/// ReelVault's metadata lives in its own versioned store, separate from every other module. Video
/// fields evolve inside the encoded JSON payload; a change to this model's shape after the first
/// installed build needs a real V2 stage and its own migration tests.
enum ReelVaultSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedVideo.self] }

    @Model final class SavedVideo {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ video: ReelVideo) throws {
            id = video.id
            payload = try JSONEncoder().encode(video)
        }
    }
}

enum ReelVaultMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [ReelVaultSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
