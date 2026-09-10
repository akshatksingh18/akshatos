import Foundation
import SwiftData

/// PageVault metadata lives in its own versioned store, logically separate from Squats.
///
/// Both models still belong to V1 because no build carrying this store has been installed on a
/// phone yet, so there is no existing container to migrate. Book fields evolve inside the encoded
/// JSON payload, but a property default is *not* enough for that: Swift's synthesized decoder
/// ignores defaults and rejects any record missing a non-optional key, which would fail the whole
/// library load. `PageVaultBook` therefore decodes field by field, and every added field must be
/// given a fallback there. A change to these model *shapes* after the first installed build
/// requires a real V2 stage and its own migration tests.
enum PageVaultSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedBook.self, SavedReadingDay.self] }

    @Model final class SavedBook {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(_ book: PageVaultBook) throws {
            id = book.id
            payload = try JSONEncoder().encode(book)
        }
    }

    @Model final class SavedReadingDay {
        /// One row per book per local day, keyed by the domain's own composite identifier.
        @Attribute(.unique) var key: String
        var payload: Data
        init(_ day: PageVaultReadingDay) throws {
            key = day.id
            payload = try JSONEncoder().encode(day)
        }
    }
}

enum PageVaultMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [PageVaultSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
