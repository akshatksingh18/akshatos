import Foundation
import SwiftData

enum SquatSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedSession.self] }

    @Model final class SavedSession {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ session: SquatSession) throws {
            id = session.id
            payload = try JSONEncoder().encode(session)
        }
    }
}

enum SquatMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SquatSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
