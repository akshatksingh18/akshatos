import Foundation
import SwiftData

/// One row per record, holding its JSON. `kind` says which domain type the payload is, so adding a
/// field to a record never needs a schema migration — only a tolerant decoder.
enum BodyLogSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedRecord.self] }

    @Model final class SavedRecord {
        @Attribute(.unique) var id: UUID
        var kind: String
        var payload: Data

        init(id: UUID, kind: String, payload: Data) {
            self.id = id
            self.kind = kind
            self.payload = payload
        }
    }
}

enum BodyLogMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [BodyLogSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
