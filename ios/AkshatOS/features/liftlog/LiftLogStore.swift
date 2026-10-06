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
    private let reminders: any LiftReminding
    private let now: () -> Date
    /// When something was last logged or changed in the active workout during this launch. Adding
    /// an exercise counts too, though only sets carry a time in the record.
    private var lastLogged: Date?
    /// Reminder changes run one after another, so a cancel can never be overtaken by an earlier
    /// schedule that was still waiting on the notification settings.
    private var reminderUpdate: Task<Void, Never>?

    init(repository: (any LiftLogRepository)? = nil, splits: (any LiftSplitStoring)? = nil,
         reminders: (any LiftReminding)? = nil, now: @escaping () -> Date = Date.init) {
        self.repository = repository ?? SwiftDataLiftLogRepository()
        self.splitStorage = splits ?? DefaultsLiftSplitStorage()
        self.reminders = reminders ?? LiftReminderService()
        self.now = now
    }

    var active: LiftWorkoutSession? { workouts.first(where: \.isActive) }

    /// The split the open workout was started from, if it still exists. A workout from before
    /// workouts remembered their split's id is matched by the split's name.
    var activeSplit: LiftSplit? {
        guard let workout = active else { return nil }
        if let id = workout.splitID { return splits.first { $0.id == id } }
        guard let name = workout.splitName else { return nil }
        return splits.first { $0.name == name }
    }
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
        updateReminder()
    }

    /// Waits for any reminder change already under way. For tests.
    func settleReminder() async { await reminderUpdate?.value }

    // MARK: - Inactivity reminder

    /// Keeps one "still working out?" reminder an hour after the last thing logged in the active
    /// workout, and none when no workout is active.
    private func updateReminder() {
        let previous = reminderUpdate
        let plan = active.flatMap { workout in
            workout.inactivityReminder(after: lastLogged ?? workout.lastActivity, now: now())
                .map { (date: $0, id: workout.id, canFinish: workout.setCount > 0) }
        }
        let reminders = reminders
        reminderUpdate = Task {
            await previous?.value
            if let plan {
                await reminders.schedule(at: plan.date, workoutID: plan.id, canFinish: plan.canFinish)
            } else {
                reminders.cancel()
            }
        }
    }

    private func logged() {
        lastLogged = now()
        updateReminder()
    }

    /// The reminder's Finish action: ends the workout it was sent for at its last logged set. A
    /// background launch may arrive before the hub has loaded anything, so it loads first.
    func finishFromReminder(workoutID: UUID) {
        if !storageAvailable { load() }
        guard var workout = active, workout.id == workoutID else { return }
        do {
            try workout.finishForgotten()
            try persistAndReplace(workout)
        } catch {
            message = error.localizedDescription
        }
        updateReminder()
    }

    // MARK: - Splits

    /// A new install starts from the default splits and saves them, so they are its own from then
    /// on. Saved splits that cannot be read are not overwritten until the next edit.
    private func loadSplits() {
        do {
            if let saved = try splitStorage.load() {
                if let upgraded = LiftSplit.upgradingCalfRaise(saved) {
                    try splitStorage.save(upgraded)
                    splits = upgraded
                } else {
                    splits = saved
                }
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
        syncActiveWorkout()
    }

    /// After a split is edited, the open workout started from it takes the change: new exercises
    /// join it, removed ones that were not logged leave, and renamed ones update.
    private func syncActiveWorkout() {
        guard var workout = active, let split = activeSplit else { return }
        let before = workout
        workout.sync(with: split)
        guard workout != before else { return }
        do { try persistAndReplace(workout) } catch {
            message = "The open workout could not take the split's change: \(error.localizedDescription)"
        }
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
        var workout = LiftWorkoutSession(startedAt: now(), splitName: split?.name, splitID: split?.id)
        if let split { workout.sync(with: split) }
        commit(workout)
        logged()
    }

    /// Adds an exercise to the open workout and, when it was started from a split, to that split
    /// too, so it is there next time without a trip to the Splits screen. An exercise the split
    /// already has (by name) is linked rather than added twice, and one already in the workout is
    /// not added again.
    func addExercise(name: String, loadMode: LiftLoadMode, equipmentNote: String) {
        guard var workout = active else { return }
        if workout.exercises.contains(where: { LiftSplit.sameName($0.name, name) }) {
            message = "\(name.trimmingCharacters(in: .whitespacesAndNewlines)) is already in this workout."
            return
        }
        do {
            var link: UUID?
            if var split = activeSplit {
                if let existing = split.exercises.first(where: { LiftSplit.sameName($0.name, name) }) {
                    link = existing.id
                } else if split.exercises.count < LiftSplit.maxExercises {
                    let added = LiftSplitExercise(name, loadMode, equipmentNote: equipmentNote)
                    split.exercises.append(added)
                    var updated = splits
                    if let index = updated.firstIndex(where: { $0.id == split.id }) { updated[index] = split }
                    try replaceSplits(updated)
                    link = added.id
                }
                workout.splitID = split.id
                if let link { workout.skippedSplitExercises?.removeAll { $0 == link } }
            }
            _ = try workout.addExercise(name: name, loadMode: loadMode,
                                        equipmentNote: equipmentNote, splitExerciseID: link)
            try persistAndReplace(workout)
            logged()
        } catch {
            message = error.localizedDescription
        }
    }

    /// Takes an exercise off the open workout, with any sets logged for it. `fromSplit` also takes
    /// it out of the split; otherwise it stays in the split for next time and only today skips it.
    func removeExercise(_ exerciseID: UUID, fromSplit: Bool) {
        guard var workout = active else { return }
        do {
            let removed = try workout.removeExercise(exerciseID)
            if let link = removed.splitExerciseID, var split = activeSplit {
                if fromSplit {
                    split.exercises.removeAll { $0.id == link }
                    var updated = splits
                    if let index = updated.firstIndex(where: { $0.id == split.id }) { updated[index] = split }
                    try replaceSplits(updated)
                } else {
                    workout.skippedSplitExercises = (workout.skippedSplitExercises ?? []) + [link]
                }
            }
            try persistAndReplace(workout)
            logged()
        } catch {
            message = error.localizedDescription
        }
    }

    /// Today's order only; the split keeps its own.
    func moveExercises(from offsets: IndexSet, to destination: Int) {
        guard var workout = active else { return }
        do {
            try workout.moveExercises(from: offsets, to: destination)
            try persistAndReplace(workout)
        } catch {
            message = error.localizedDescription
        }
    }

    func removeSet(exerciseID: UUID, setID: UUID) {
        guard var workout = active else { return }
        do {
            try workout.removeSet(exerciseID: exerciseID, setID: setID)
            try persistAndReplace(workout)
            logged()
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
            logged()
        } catch {
            message = error.localizedDescription
        }
    }

    func updateSet(exerciseID: UUID, setID: UUID, reps: Int, load: Double) {
        guard var workout = active else { return }
        do {
            try workout.updateSet(exerciseID: exerciseID, setID: setID, reps: reps, load: load)
            try persistAndReplace(workout)
            logged()
        } catch {
            message = error.localizedDescription
        }
    }

    func removeLastSet(exerciseID: UUID) {
        guard var workout = active else { return }
        do {
            try workout.removeLastSet(exerciseID: exerciseID)
            try persistAndReplace(workout)
            logged()
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
        updateReminder()
    }

    func deleteWorkout(_ id: UUID) {
        do {
            try repository.delete(id: id)
            workouts.removeAll { $0.id == id }
        } catch {
            message = "The workout could not be deleted: \(error.localizedDescription)"
        }
        updateReminder()
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
            lastLogged = nil
            updateReminder()
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
