import SwiftData
import XCTest
@testable import AkshatOS

@MainActor final class LiftLogPersistenceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: LiftLogSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: LiftLogMigration.self,
                                  configurations: [ModelConfiguration(schema: schema,
                                                                      isStoredInMemoryOnly: true)])
    }

    func testRepositoryRoundTripKeepsPerSideMeaning() throws {
        let repository = SwiftDataLiftLogRepository(container: try makeContainer())
        var workout = LiftWorkoutSession(startedAt: Date(timeIntervalSince1970: 1_790_105_400))
        let exercise = try workout.addExercise(name: "Plate-loaded row", loadMode: .platesPerSide,
                                               equipmentNote: "machine base unknown")
        try workout.addSet(exerciseID: exercise, reps: 9, load: 42.5)
        try repository.save(workout)

        let restored = try XCTUnwrap(repository.load().first)
        XCTAssertEqual(restored.exercises.first?.loadMode, .platesPerSide)
        XCTAssertEqual(restored.exercises.first?.sets.first?.load, 42.5)
        XCTAssertEqual(restored.exercises.first?.equipmentNote, "machine base unknown")
    }

    func testRepositoryUpsertsWithoutDuplicatingWorkout() throws {
        let repository = SwiftDataLiftLogRepository(container: try makeContainer())
        var workout = LiftWorkoutSession()
        let exercise = try workout.addExercise(name: "Chest-supported row", loadMode: .platesPerSide)
        try repository.save(workout)
        try workout.addSet(exerciseID: exercise, reps: 11, load: 47.5)
        try repository.save(workout)

        let restored = try repository.load()
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.setCount, 1)
    }

    func testStorePersistsEveryMutationAndReopensActiveWorkout() throws {
        let container = try makeContainer()
        let first = LiftLogStore(repository: SwiftDataLiftLogRepository(container: container),
                                 now: { Date(timeIntervalSince1970: 1_790_105_400) })
        first.load()
        first.startWorkout(template: .lower)
        let exercise = try XCTUnwrap(first.active?.exercises.first)
        first.addSet(exerciseID: exercise.id, reps: 7, load: 82.5)

        let reopened = LiftLogStore(repository: SwiftDataLiftLogRepository(container: container))
        reopened.load()
        XCTAssertTrue(reopened.storageAvailable)
        XCTAssertEqual(reopened.active?.setCount, 1)
        XCTAssertEqual(reopened.active?.exercises.first?.sets.first?.load, 82.5)
        XCTAssertEqual(reopened.active?.exercises.map(\.name), LiftWorkoutTemplate.lower.exercises.map(\.name))
        XCTAssertEqual(reopened.recentExercises.first?.loadMode, .platesPerSide)
        XCTAssertEqual(reopened.recentExercises.first?.equipmentNote, "Smith bar resistance excluded")
    }

    func testBackupRestoreValidatesBeforeReplacing() throws {
        let repository = SwiftDataLiftLogRepository(container: try makeContainer())
        let store = LiftLogStore(repository: repository,
                                 now: { Date(timeIntervalSince1970: 1_790_105_400) })
        store.load()
        store.startWorkout(template: .upper)
        let exercise = try XCTUnwrap(store.active?.exercises.first)
        store.addSet(exerciseID: exercise.id, reps: 12, load: 37.5)
        let backup = try store.backupData()

        store.deleteWorkout(try XCTUnwrap(store.active?.id))
        XCTAssertTrue(store.workouts.isEmpty)
        store.restoreBackup(backup)
        XCTAssertEqual(store.active?.setCount, 1)

        store.restoreBackup(Data("not json".utf8))
        XCTAssertEqual(store.active?.setCount, 1, "Invalid restore must not replace valid data")
        XCTAssertNotNil(store.message)
    }

    func testCSVUsesExplicitLoadModeAndEscapesNotes() throws {
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()),
                                 now: { Date(timeIntervalSince1970: 1_790_105_400) })
        store.load()
        store.startWorkout(template: .lower)
        store.addExercise(name: "Plate-loaded row", loadMode: .platesPerSide,
                          equipmentNote: "Station B, base unknown")
        let exercise = try XCTUnwrap(store.active?.exercises.last)
        store.addSet(exerciseID: exercise.id, reps: 9, load: 42.5)
        let csv = try XCTUnwrap(String(data: store.csvData(), encoding: .utf8))
        XCTAssertTrue(csv.contains("platesPerSide,42.5,9,1"))
        XCTAssertTrue(csv.contains("\"Station B, base unknown\""))
    }

    func testTemplatePriorityLastPerformanceAndSetEditing() throws {
        var clock = Date(timeIntervalSince1970: 1_790_105_400)
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()),
                                 now: { clock })
        store.load()
        store.startWorkout(template: .upper)
        XCTAssertEqual(store.active?.exercises.map(\.name), LiftWorkoutTemplate.upper.exercises.map(\.name))

        let firstBench = try XCTUnwrap(store.active?.exercises.first(where: {
            $0.name == "Dumbbell bench press"
        }))
        store.addSet(exerciseID: firstBench.id, reps: 10, load: 50)
        store.finishWorkout()
        XCTAssertEqual(store.finished.first?.exercises.map(\.name), ["Dumbbell bench press"],
                       "Unperformed lower-priority template exercises should not pollute history")

        clock = clock.addingTimeInterval(86_400)
        store.startWorkout(template: .upper)
        let currentBench = try XCTUnwrap(store.active?.exercises.first(where: {
            $0.name == "Dumbbell bench press"
        }))
        let reference = try XCTUnwrap(store.lastPerformance(for: currentBench))
        XCTAssertEqual(reference.exercise.sets.first?.load, 50)
        XCTAssertEqual(reference.exercise.sets.first?.reps, 10)

        store.addSet(exerciseID: currentBench.id, reps: 8, load: 55)
        let currentSet = try XCTUnwrap(store.exercise(currentBench.id)?.sets.first)
        store.updateSet(exerciseID: currentBench.id, setID: currentSet.id, reps: 9, load: 57.5)
        XCTAssertEqual(store.exercise(currentBench.id)?.sets.first?.reps, 9)
        XCTAssertEqual(store.exercise(currentBench.id)?.sets.first?.load, 57.5)
        XCTAssertEqual(store.lastPerformance(for: currentBench)?.exercise.sets.first?.load, 50,
                       "Editing the active workout must not change the prior reference")
    }
}
