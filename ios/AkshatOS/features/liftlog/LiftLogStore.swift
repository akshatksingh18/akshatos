import Foundation
import SwiftUI

@MainActor final class LiftLogStore: ObservableObject {
    @Published private(set) var workouts: [LiftWorkoutSession] = []
    @Published private(set) var storageAvailable = false
    /// The workout days, in the order shown when starting a workout. Edited in the app.
    @Published private(set) var splits: [LiftSplit] = []
    @Published var message: String?

    private let repository: any LiftLogRepository
    private let splitStorage: any LiftSplitStoring
    private let now: () -> Date

    init(repository: (any LiftLogRepository)? = nil, splits: (any LiftSplitStoring)? = nil,
         now: @escaping () -> Date = Date.init) {
        self.repository = repository ?? SwiftDataLiftLogRepository()
        self.splitStorage = splits ?? DefaultsLiftSplitStorage()
        self.now = now
    }

    var active: LiftWorkoutSession? { workouts.first(where: \.isActive) }
    var finished: [LiftWorkoutSession] { workouts.filter { !$0.isActive } }
    var totalSetCount: Int { workouts.reduce(0) { $0 + $1.setCount } }

    var recentExercises: [LiftExerciseSuggestion] {
        var seen = Set<String>()
        return workouts.flatMap(\.exercises).compactMap { exercise in
            let key = exercise.name.lowercased()
            guard seen.insert(key).inserted else { return nil }
            return LiftExerciseSuggestion(name: exercise.name, loadMode: exercise.loadMode,
                                          equipmentNote: exercise.equipmentNote)
        }
    }

    func load() {
        do {
            workouts = try repository.load()
            storageAvailable = true
        } catch {
            storageAvailable = false
            message = "Your lift history could not be read: \(error.localizedDescription)"
        }
        loadSplits()
    }

    // MARK: - Splits

    /// A new install starts from the default splits and saves them, so they are its own from then
    /// on. Saved splits that cannot be read are not overwritten until the next edit.
    private func loadSplits() {
        do {
            if let saved = try splitStorage.load() {
                splits = saved
            } else {
                splits = LiftSplit.starting
                try splitStorage.save(splits)
            }
        } catch {
            if splits.isEmpty { splits = LiftSplit.starting }
            message = "Your splits could not be read, so the starting splits are shown: \(error.localizedDescription)"
        }
    }

    /// Adds a new split or replaces the one with the same id. Throws, without changing anything,
    /// when the split or the resulting list is invalid, so the editor can say why.
    func saveSplit(_ split: LiftSplit) throws {
        var updated = splits
        if let index = updated.firstIndex(where: { $0.id == split.id }) {
            updated[index] = split
        } else {
            updated.append(split)
        }
        try replaceSplits(updated)
    }

    func deleteSplit(_ id: UUID) {
        do { try replaceSplits(splits.filter { $0.id != id }) } catch { message = error.localizedDescription }
    }

    func moveSplits(from source: IndexSet, to destination: Int) {
        var updated = splits
        updated.move(fromOffsets: source, toOffset: destination)
        do { try replaceSplits(updated) } catch { message = error.localizedDescription }
    }

    private func replaceSplits(_ updated: [LiftSplit]) throws {
        let checked = try LiftSplit.validatedList(updated)
        try splitStorage.save(checked)
        splits = checked
    }

    /// Starts from a split's exercises in order, or with none when `split` is nil.
    func startWorkout(split: LiftSplit?) {
        guard storageAvailable else {
            message = "Lift Log storage is unavailable."
            return
        }
        guard active == nil else {
            message = LiftLogError.activeWorkoutExists.localizedDescription
            return
        }
        var workout = LiftWorkoutSession(startedAt: now(), splitName: split?.name)
        do {
            for exercise in split?.exercises ?? [] {
                _ = try workout.addExercise(name: exercise.name, loadMode: exercise.loadMode,
                                            equipmentNote: exercise.equipmentNote)
            }
            commit(workout)
        } catch {
            message = "\(split?.name ?? "The workout") could not be started: \(error.localizedDescription)"
        }
    }

    func addExercise(name: String, loadMode: LiftLoadMode, equipmentNote: String) {
        guard var workout = active else { return }
        do {
            _ = try workout.addExercise(name: name, loadMode: loadMode,
                                        equipmentNote: equipmentNote)
            try persistAndReplace(workout)
        } catch {
            message = error.localizedDescription
        }
    }

    func addSet(exerciseID: UUID, reps: Int, load: Double) {
        guard var workout = active else { return }
        do {
            try workout.addSet(exerciseID: exerciseID, reps: reps, load: load,
                               completedAt: now())
            try persistAndReplace(workout)
        } catch {
            message = error.localizedDescription
        }
    }

    func updateSet(exerciseID: UUID, setID: UUID, reps: Int, load: Double) {
        guard var workout = active else { return }
        do {
            try workout.updateSet(exerciseID: exerciseID, setID: setID, reps: reps, load: load)
            try persistAndReplace(workout)
        } catch {
            message = error.localizedDescription
        }
    }

    func removeLastSet(exerciseID: UUID) {
        guard var workout = active else { return }
        do {
            try workout.removeLastSet(exerciseID: exerciseID)
            try persistAndReplace(workout)
        } catch {
            message = error.localizedDescription
        }
    }

    func finishWorkout() {
        guard var workout = active else { return }
        do {
            try workout.finish(at: now())
            try persistAndReplace(workout)
        } catch {
            message = error.localizedDescription
        }
    }

    func deleteWorkout(_ id: UUID) {
        do {
            try repository.delete(id: id)
            workouts.removeAll { $0.id == id }
        } catch {
            message = "The workout could not be deleted: \(error.localizedDescription)"
        }
    }

    func exercise(_ id: UUID) -> LiftExerciseRecord? {
        active?.exercises.first { $0.id == id }
    }

    func lastPerformance(for exercise: LiftExerciseRecord) -> LiftPerformanceReference? {
        let name = Self.normalizedExerciseName(exercise.name)
        for workout in finished.sorted(by: { $0.startedAt > $1.startedAt }) {
            guard let match = workout.exercises.first(where: {
                Self.normalizedExerciseName($0.name) == name &&
                    $0.loadMode == exercise.loadMode && !$0.sets.isEmpty
            }) else { continue }
            return LiftPerformanceReference(workoutDate: workout.startedAt, exercise: match)
        }
        return nil
    }

    func backupData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(LiftLogBackup(exportedAt: now(), workouts: workouts, splits: splits))
    }

    func csvData() -> Data {
        var lines = ["date,exercise,load_mode,load_lbs,reps,set,equipment_notes"]
        let formatter = ISO8601DateFormatter()
        for workout in workouts.sorted(by: { $0.startedAt < $1.startedAt }) {
            for exercise in workout.exercises {
                for (index, set) in exercise.sets.enumerated() {
                    lines.append([
                        formatter.string(from: set.completedAt),
                        exercise.name,
                        exercise.loadMode.rawValue,
                        Self.weightText(set.load),
                        String(set.reps),
                        String(index + 1),
                        exercise.equipmentNote
                    ].map(Self.csvField).joined(separator: ","))
                }
            }
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    /// Decodes and checks a backup without changing anything.
    static func validatedBackup(_ data: Data) throws -> (workouts: [LiftWorkoutSession], splits: [LiftSplit]?) {
        let backup = try JSONDecoder().decode(LiftLogBackup.self, from: data)
        return (try backup.validatedWorkouts(), try backup.validatedSplits())
    }

    @discardableResult
    func restoreBackup(_ data: Data) -> Bool {
        do {
            let restored = try Self.validatedBackup(data)
            // Splits first: if the workouts then fail to save, the previous splits go back.
            let previousSplits = splits
            if let restoredSplits = restored.splits { try splitStorage.save(restoredSplits) }
            do {
                try repository.replaceAll(with: restored.workouts)
            } catch {
                try? splitStorage.save(previousSplits)
                throw error
            }
            workouts = restored.workouts
            if let restoredSplits = restored.splits { splits = restoredSplits }
            storageAvailable = true
            return true
        } catch {
            message = "That Lift Log backup is invalid and nothing was replaced: \(error.localizedDescription)"
            return false
        }
    }

    private func commit(_ workout: LiftWorkoutSession) {
        do {
            try repository.save(workout)
            workouts.insert(workout, at: 0)
        } catch {
            message = "The workout could not be saved: \(error.localizedDescription)"
        }
    }

    private func persistAndReplace(_ workout: LiftWorkoutSession) throws {
        try repository.save(workout)
        guard let index = workouts.firstIndex(where: { $0.id == workout.id }) else {
            workouts.insert(workout, at: 0)
            return
        }
        workouts[index] = workout
        workouts.sort { $0.startedAt > $1.startedAt }
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else { return value }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    /// Every set of a previous performance, in order — "S1 45 lb/side × 8 · S2 …". All of them,
    /// never "+1 more": the point of the reference is knowing exactly what was lifted.
    static func performanceSummary(_ exercise: LiftExerciseRecord) -> String {
        exercise.sets.enumerated().map { index, set in
            "S\(index + 1) \(weightText(set.load)) \(exercise.loadMode.shortUnit) × \(set.reps)"
        }.joined(separator: " · ")
    }

    static func weightText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }

    private static func normalizedExerciseName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct LiftPerformanceReference: Equatable {
    let workoutDate: Date
    let exercise: LiftExerciseRecord
}

struct LiftExerciseSuggestion: Identifiable, Equatable {
    var id: String { name.lowercased() }
    let name: String
    let loadMode: LiftLoadMode
    let equipmentNote: String
}
