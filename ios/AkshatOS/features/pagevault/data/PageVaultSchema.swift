import Foundation
import SwiftData

/// PageVault metadata lives in its own versioned store, logically separate from Squats.
enum PageVaultSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedBook.self] }

    @Model final class SavedBook {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ book: PageVaultBook) throws {
            id = book.id
            payload = try JSONEncoder().encode(book)
        }
    }
}

enum PageVaultMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PageVaultSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
