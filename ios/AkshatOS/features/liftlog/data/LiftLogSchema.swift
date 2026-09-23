import Foundation
import SwiftData

enum LiftLogSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [SavedWorkout.self] }

    @Model final class SavedWorkout {
        @Attribute(.unique) var id: UUID
        var payload: Data

        init(_ workout: LiftWorkoutSession) throws {
            id = workout.id
            payload = try JSONEncoder().encode(workout)
        }
    }
}

enum LiftLogMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [LiftLogSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
