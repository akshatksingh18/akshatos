import Foundation
import SwiftData

@MainActor protocol LiftLogRepository {
    func load() throws -> [LiftWorkoutSession]
    func save(_ workout: LiftWorkoutSession) throws
    func delete(id: UUID) throws
    func replaceAll(with workouts: [LiftWorkoutSession]) throws
}

@MainActor final class SwiftDataLiftLogRepository: LiftLogRepository {
    private var container: ModelContainer?

    init(container: ModelContainer? = nil) { self.container = container }

    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: LiftLogSchemaV1.self)
            container = try ModelContainer(for: schema, migrationPlan: LiftLogMigration.self,
                configurations: [ModelConfiguration("LiftLog", schema: schema)])
        }
        return container!.mainContext
    }

    func load() throws -> [LiftWorkoutSession] {
        let rows = try context().fetch(FetchDescriptor<LiftLogSchemaV1.SavedWorkout>())
        let workouts = try rows.map {
            try JSONDecoder().decode(LiftWorkoutSession.self, from: $0.payload).validated()
        }
        guard Set(workouts.map(\.id)).count == workouts.count,
              zip(rows, workouts).allSatisfy({ $0.0.id == $0.1.id }),
              workouts.filter(\.isActive).count <= 1 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return workouts.sorted { $0.startedAt > $1.startedAt }
    }

    func save(_ workout: LiftWorkoutSession) throws {
        let checked = try workout.validated()
        let context = try context()
        do {
            let rows = try context.fetch(FetchDescriptor<LiftLogSchemaV1.SavedWorkout>())
            let payload = try JSONEncoder().encode(checked)
            if let row = rows.first(where: { $0.id == checked.id }) { row.payload = payload }
            else { context.insert(try LiftLogSchemaV1.SavedWorkout(checked)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(id: UUID) throws {
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<LiftLogSchemaV1.SavedWorkout>()) where row.id == id {
                context.delete(row)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func replaceAll(with workouts: [LiftWorkoutSession]) throws {
        let checked = try LiftLogBackup(workouts: workouts).validatedWorkouts()
        let context = try context()
        do {
            for row in try context.fetch(FetchDescriptor<LiftLogSchemaV1.SavedWorkout>()) {
                context.delete(row)
            }
            for workout in checked { context.insert(try LiftLogSchemaV1.SavedWorkout(workout)) }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
