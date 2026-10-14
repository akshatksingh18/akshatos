import Foundation
import SwiftData

/// Study blocks as versioned SwiftData rows. Each row carries the block as JSON, so new fields
/// evolve inside the payload, as in Lift Log.
enum StudyLogSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedSegment.self] }

    @Model final class SavedSegment {
        @Attribute(.unique) var id: UUID
        var payload: Data

        init(_ segment: StudySegment) throws {
            id = segment.id
            payload = try JSONEncoder().encode(segment)
        }
    }
}

enum StudyLogMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StudyLogSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
