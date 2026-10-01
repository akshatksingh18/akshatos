import SwiftData
import XCTest
@testable import AkshatOS

/// Splits kept in memory so no test reads or writes the host app's preferences.
@MainActor final class MemoryLiftSplits: LiftSplitStoring {
    var saved: [LiftSplit]?
    var failSave = false
    func load() throws -> [LiftSplit]? { saved }
    func save(_ splits: [LiftSplit]) throws {
        if failSave { throw CocoaError(.fileWriteUnknown) }
        saved = splits
    }
}

@MainActor final class LiftLogPersistenceTests: XCTestCase {
    private func split(_ store: LiftLogStore, _ name: String) throws -> LiftSplit {
        try XCTUnwrap(store.splits.first { $0.name == name }, "\(name) is a starting split")
    }
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
        let first = LiftLogStore(repository: SwiftDataLiftLogRepository(container: container), splits: MemoryLiftSplits(),
                                 now: { Date(timeIntervalSince1970: 1_790_105_400) })
        first.load()
        first.startWorkout(split: try split(first, "Lower day"))
        let exercise = try XCTUnwrap(first.active?.exercises.first)
        first.addSet(exerciseID: exercise.id, reps: 7, load: 82.5)

        let reopened = LiftLogStore(repository: SwiftDataLiftLogRepository(container: container), splits: MemoryLiftSplits())
        reopened.load()
        XCTAssertTrue(reopened.storageAvailable)
        XCTAssertEqual(reopened.active?.setCount, 1)
        XCTAssertEqual(reopened.active?.exercises.first?.sets.first?.load, 82.5)
        XCTAssertEqual(reopened.active?.exercises.map(\.name), LiftSplit.starting[0].exercises.map(\.name))
        XCTAssertEqual(reopened.recentExercises.first?.loadMode, .platesPerSide)
        XCTAssertEqual(reopened.recentExercises.first?.equipmentNote, "Smith bar resistance excluded")
    }

    func testBackupRestoreValidatesBeforeReplacing() throws {
        let repository = SwiftDataLiftLogRepository(container: try makeContainer())
        let store = LiftLogStore(repository: repository, splits: MemoryLiftSplits(),
                                 now: { Date(timeIntervalSince1970: 1_790_105_400) })
        store.load()
        store.startWorkout(split: try split(store, "Chest day"))
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
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()), splits: MemoryLiftSplits(),
                                 now: { Date(timeIntervalSince1970: 1_790_105_400) })
        store.load()
        store.startWorkout(split: try split(store, "Lower day"))
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
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()), splits: MemoryLiftSplits(),
                                 now: { clock })
        store.load()
        store.startWorkout(split: try split(store, "Chest day"))
        XCTAssertEqual(store.active?.exercises.map(\.name), try split(store, "Chest day").exercises.map(\.name))

        let firstBench = try XCTUnwrap(store.active?.exercises.first(where: {
            $0.name == "Dumbbell bench press"
        }))
        store.addSet(exerciseID: firstBench.id, reps: 10, load: 50)
        store.finishWorkout()
        XCTAssertEqual(store.finished.first?.exercises.map(\.name), ["Dumbbell bench press"],
                       "Unperformed lower-priority split exercises should not pollute history")

        clock = clock.addingTimeInterval(86_400)
        store.startWorkout(split: try split(store, "Chest day"))
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

    func testLastPerformanceShowsEverySetRatherThanACount() throws {
        var clock = Date(timeIntervalSince1970: 1_790_105_400)
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()), splits: MemoryLiftSplits(),
                                 now: { clock })
        store.load()
        store.startWorkout(split: try split(store, "Chest day"))
        let bench = try XCTUnwrap(store.active?.exercises.first { $0.name == "Dumbbell bench press" })
        for (reps, load) in [(10, 50.0), (9, 50.0), (8, 52.5), (6, 55.0)] {
            store.addSet(exerciseID: bench.id, reps: reps, load: load)
        }
        store.finishWorkout()

        clock = clock.addingTimeInterval(86_400)
        store.startWorkout(split: try split(store, "Chest day"))
        let next = try XCTUnwrap(store.active?.exercises.first { $0.name == "Dumbbell bench press" })
        let reference = try XCTUnwrap(store.lastPerformance(for: next))
        let unit = next.loadMode.shortUnit
        XCTAssertEqual(LiftLogStore.performanceSummary(reference.exercise),
                       "S1 50 \(unit) × 10 · S2 50 \(unit) × 9 · S3 52.5 \(unit) × 8 · S4 55 \(unit) × 6",
                       "The fourth set is shown, not hidden behind \"+1 more\"")
    }

    func testHistoryKeepsEveryFinishedWorkoutReachable() throws {
        var clock = Date(timeIntervalSince1970: 1_790_105_400)
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()), splits: MemoryLiftSplits(),
                                 now: { clock })
        store.load()
        for _ in 0..<15 {
            store.startWorkout(split: try split(store, "Lower day"))
            let first = try XCTUnwrap(store.active?.exercises.first)
            store.addSet(exerciseID: first.id, reps: 8, load: 45)
            store.finishWorkout()
            clock = clock.addingTimeInterval(3 * 86_400)
        }
        let months = LiftWorkoutSession.byMonth(store.workouts)
        XCTAssertEqual(months.flatMap(\.workouts).count, 15,
                       "All 15 finished workouts are in the history, past the 12 the main screen used to show")
        XCTAssertEqual(Set(months.flatMap(\.workouts).map(\.id)), Set(store.finished.map(\.id)))
    }

    func testANewInstallStartsWithLowerBackAndBicepsAndChest() throws {
        let storage = MemoryLiftSplits()
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()),
                                 splits: storage)
        store.load()
        XCTAssertEqual(store.splits.map(\.name), ["Lower day", "Back and biceps day", "Chest day"])
        XCTAssertEqual(storage.saved, store.splits, "The starting splits are saved, so later edits stick")
        XCTAssertEqual(try split(store, "Back and biceps day").exercises.map(\.name),
                       ["Weighted pull-ups", "Seated cable row", "Dumbbell biceps curl"])
    }

    func testSplitsAreAddedEditedReorderedAndDeletedAndSurviveReopening() throws {
        let storage = MemoryLiftSplits()
        let container = try makeContainer()
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: container), splits: storage)
        store.load()

        var shoulders = LiftSplit(name: "  Shoulder day ", exercises: [LiftSplitExercise("Lateral raise", .perHand)])
        try store.saveSplit(shoulders)
        XCTAssertEqual(store.splits.last?.name, "Shoulder day", "Names are trimmed")

        shoulders.name = "Shoulders and arms"
        shoulders.exercises.append(LiftSplitExercise("Hammer curl", .perHand))
        try store.saveSplit(shoulders)
        XCTAssertEqual(store.splits.count, 4, "Saving an existing split replaces it")
        XCTAssertEqual(store.splits.last?.exercises.map(\.name), ["Lateral raise", "Hammer curl"])

        store.moveSplits(from: IndexSet(integer: 3), to: 0)
        XCTAssertEqual(store.splits.first?.name, "Shoulders and arms")
        store.deleteSplit(try split(store, "Chest day").id)

        let reopened = LiftLogStore(repository: SwiftDataLiftLogRepository(container: container), splits: storage)
        reopened.load()
        XCTAssertEqual(reopened.splits.map(\.name), ["Shoulders and arms", "Lower day", "Back and biceps day"])
    }

    func testAnInvalidSplitIsRefusedAndNothingChanges() throws {
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()),
                                 splits: MemoryLiftSplits())
        store.load()
        let before = store.splits
        XCTAssertThrowsError(try store.saveSplit(LiftSplit(name: "   "))) {
            XCTAssertEqual($0 as? LiftLogError, .emptySplitName)
        }
        XCTAssertThrowsError(try store.saveSplit(LiftSplit(name: "chest DAY"))) {
            XCTAssertEqual($0 as? LiftLogError, .duplicateSplitName, "Names are compared ignoring case")
        }
        XCTAssertThrowsError(try store.saveSplit(LiftSplit(name: "Arms", exercises: [LiftSplitExercise(" ", .stack)])))
        XCTAssertEqual(store.splits, before)
    }

    func testAnEmptyWorkoutTakesExercisesAddedAsYouGoAndHistoryKeepsTheSplitName() throws {
        var clock = Date(timeIntervalSince1970: 1_790_105_400)
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()),
                                 splits: MemoryLiftSplits(), now: { clock })
        store.load()
        store.startWorkout(split: nil)
        XCTAssertEqual(store.active?.exercises.count, 0)
        XCTAssertNil(store.active?.splitName)
        store.addExercise(name: "Farmer carry", loadMode: .perHand, equipmentNote: "")
        let carry = try XCTUnwrap(store.active?.exercises.first)
        store.addSet(exerciseID: carry.id, reps: 1, load: 70)
        store.finishWorkout()
        XCTAssertEqual(store.finished.first?.exercises.map(\.name), ["Farmer carry"])

        clock = clock.addingTimeInterval(86_400)
        var chest = try split(store, "Chest day")
        store.startWorkout(split: chest)
        XCTAssertEqual(store.active?.splitName, "Chest day")
        store.addExercise(name: "Cable crossover", loadMode: .stack, equipmentNote: "")
        XCTAssertEqual(store.active?.exercises.last?.name, "Cable crossover", "Added after the split's own exercises")
        let bench = try XCTUnwrap(store.active?.exercises.first)
        store.addSet(exerciseID: bench.id, reps: 8, load: 55)
        store.finishWorkout()

        chest.name = "Push day"
        try store.saveSplit(chest)
        XCTAssertEqual(store.finished.first?.splitName, "Chest day", "Renaming a split never rewrites history")
    }

    func testTheBackupCarriesSplitsAndAnOlderBackupLeavesThemAlone() throws {
        let store = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()),
                                 splits: MemoryLiftSplits())
        store.load()
        try store.saveSplit(LiftSplit(name: "Arms day", exercises: [LiftSplitExercise("Preacher curl", .stack)]))
        let backup = try store.backupData()

        let freshStorage = MemoryLiftSplits()
        let fresh = LiftLogStore(repository: SwiftDataLiftLogRepository(container: try makeContainer()),
                                 splits: freshStorage)
        fresh.load()
        XCTAssertTrue(fresh.restoreBackup(backup))
        XCTAssertEqual(fresh.splits.map(\.name), store.splits.map(\.name))
        XCTAssertEqual(freshStorage.saved?.last?.name, "Arms day", "Restored splits are saved, not only shown")

        let older = try JSONEncoder().encode(LiftLogBackup(workouts: []))
        let kept = fresh.splits
        XCTAssertTrue(fresh.restoreBackup(older))
        XCTAssertEqual(fresh.splits, kept, "A backup from before splits existed keeps the current splits")
    }

    func testFailedWorkoutRestorePutsThePreviousSplitsBack() throws {
        let failing = FailingLiftRepository()
        let storage = MemoryLiftSplits()
        let store = LiftLogStore(repository: failing, splits: storage)
        store.load()
        let before = store.splits
        let backup = try JSONEncoder().encode(LiftLogBackup(workouts: [], splits: [LiftSplit(name: "Only this")]))
        failing.failReplace = true
        XCTAssertFalse(store.restoreBackup(backup))
        XCTAssertEqual(storage.saved, before, "The splits written first are rolled back")
        XCTAssertEqual(store.splits, before)
    }
}

@MainActor private final class FailingLiftRepository: LiftLogRepository {
    var failReplace = false
    func load() throws -> [LiftWorkoutSession] { [] }
    func save(_ workout: LiftWorkoutSession) throws {}
    func delete(id: UUID) throws {}
    func replaceAll(with workouts: [LiftWorkoutSession]) throws {
        if failReplace { throw CocoaError(.fileWriteUnknown) }
    }
}
