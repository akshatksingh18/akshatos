import Foundation

enum LiftLoadMode: String, Codable, CaseIterable, Identifiable {
    case platesPerSide
    case perHand
    case stack
    case addedWeight
    case weightLoaded
    case total

    var id: String { rawValue }

    var title: String {
        switch self {
        case .platesPerSide: return "Plates per side"
        case .perHand: return "Weight per hand"
        case .stack: return "Stack setting"
        case .addedWeight: return "Added weight"
        case .weightLoaded: return "Weight loaded"
        case .total: return "Total weight"
        }
    }

    var shortUnit: String {
        switch self {
        case .platesPerSide: return "lb/side"
        case .perHand: return "lb/hand"
        case .stack: return "lb stack"
        case .addedWeight: return "lb added"
        case .weightLoaded: return "lb loaded"
        case .total: return "lb total"
        }
    }

    var guidance: String {
        switch self {
        case .platesPerSide:
            return "Enter the plates loaded on one side; the bar, sled, or machine base stays excluded."
        case .perHand:
            return "Enter the weight held in one hand; do not add both dumbbells or handles together."
        case .stack:
            return "Enter the number selected on the machine's weight stack; do not guess pulley-adjusted resistance."
        case .addedWeight:
            return "Enter only the external weight added to a bodyweight exercise; your bodyweight stays excluded."
        case .weightLoaded:
            return "Enter all the plates on the machine added together, as one number; the machine's own resistance stays excluded."
        case .total:
            return "Enter the complete known load, including the bar or machine base only when you actually know it."
        }
    }

    var example: String {
        switch self {
        case .platesPerSide:
            return "Example: 25 lb on each side of a Smith squat → enter 25."
        case .perHand:
            return "Example: dumbbell bench with 50 lb dumbbells → enter 50."
        case .stack:
            return "Example: seated cable row with the pin at 70 lb → enter 70."
        case .addedWeight:
            return "Example: weighted pull-ups with a 25 lb plate → enter 25."
        case .weightLoaded:
            return "Example: seated calf raise with two 45 lb plates and a 25 → enter 115."
        case .total:
            return "Example: a 45 lb bar plus 25 lb per side is 95 lb total → enter 95."
        }
    }
}

/// One exercise in a split, in priority order.
struct LiftSplitExercise: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var loadMode: LiftLoadMode
    var equipmentNote: String

    init(id: UUID = UUID(), _ name: String, _ loadMode: LiftLoadMode, equipmentNote: String = "") {
        self.id = id
        self.name = name
        self.loadMode = loadMode
        self.equipmentNote = equipmentNote
    }
}

/// A workout day Akshat names and fills himself, such as "Chest day". Starting a workout from it
/// loads its exercises in order; lower entries can be left empty when time is short.
struct LiftSplit: Identifiable, Codable, Equatable {
    static let maxNameLength = 40
    /// Room for alternates: a split can hold the exercises you rotate between, and only the ones
    /// you log are saved with a workout.
    static let maxExercises = 40
    static let maxSplits = 20

    var id: UUID
    var name: String
    var exercises: [LiftSplitExercise]

    init(id: UUID = UUID(), name: String, exercises: [LiftSplitExercise] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }

    /// Trimmed and checked: a name, at most 40 exercises, each with a name.
    func validated() throws -> LiftSplit {
        var checked = self
        checked.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !checked.name.isEmpty else { throw LiftLogError.emptySplitName }
        guard checked.name.count <= Self.maxNameLength, exercises.count <= Self.maxExercises else {
            throw LiftLogError.splitTooLarge
        }
        guard Set(exercises.map(\.id)).count == exercises.count else { throw LiftLogError.duplicateIdentifier }
        checked.exercises = try exercises.map { exercise in
            var trimmed = exercise
            trimmed.name = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            trimmed.equipmentNote = exercise.equipmentNote.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.name.isEmpty else { throw LiftLogError.emptyExerciseName }
            return trimmed
        }
        return checked
    }

    /// The whole list: each split valid, no two with the same id or the same name, at most 20.
    static func validatedList(_ splits: [LiftSplit]) throws -> [LiftSplit] {
        let checked = try splits.map { try $0.validated() }
        guard checked.count <= maxSplits else { throw LiftLogError.splitTooLarge }
        guard Set(checked.map(\.id)).count == checked.count else { throw LiftLogError.duplicateIdentifier }
        guard Set(checked.map { $0.name.lowercased() }).count == checked.count else {
            throw LiftLogError.duplicateSplitName
        }
        return checked
    }

    /// Names compare ignoring case and surrounding spaces, so "Hammer curl" is one exercise.
    static func sameName(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            == b.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// What a new install starts with: Lower as before, and the old Upper day split into two.
    /// Every one of them can be renamed, edited, reordered or deleted in the app.
    static var starting: [LiftSplit] {
        [
            LiftSplit(name: "Lower day", exercises: [
                LiftSplitExercise("Smith-machine squat", .platesPerSide,
                                  equipmentNote: "Smith bar resistance excluded"),
                LiftSplitExercise("Barbell Romanian deadlift", .platesPerSide,
                                  equipmentNote: "Bar weight excluded"),
                LiftSplitExercise("Leg press", .platesPerSide,
                                  equipmentNote: "Sled/base resistance excluded"),
                LiftSplitExercise("Seated machine leg curl", .stack),
                LiftSplitExercise("Seated calf raise", .weightLoaded,
                                  equipmentNote: Self.calfRaiseNote)
            ]),
            LiftSplit(name: "Back and biceps day", exercises: [
                LiftSplitExercise("Weighted pull-ups", .addedWeight),
                LiftSplitExercise("Seated cable row", .stack),
                LiftSplitExercise("Dumbbell biceps curl", .perHand)
            ]),
            LiftSplit(name: "Chest day", exercises: [
                LiftSplitExercise("Dumbbell bench press", .perHand),
                LiftSplitExercise("Shoulder press", .perHand, equipmentNote: "Default: dumbbells"),
                LiftSplitExercise("Pec-deck fly", .stack),
                LiftSplitExercise("Triceps pushdown", .stack)
            ])
        ]
    }
}

extension LiftSplit {
    static let calfRaiseNote = "Machine's own resistance excluded"

    /// Splits saved before "Weight loaded" existed start the seated calf raise as plates per side,
    /// which does not fit a machine loaded on one post. Only that untouched starting entry moves to
    /// the new mode; anything Akshat set himself is left alone. Nil when nothing changes.
    static func upgradingCalfRaise(_ splits: [LiftSplit]) -> [LiftSplit]? {
        var changed = false
        let upgraded = splits.map { split -> LiftSplit in
            var split = split
            for index in split.exercises.indices {
                let exercise = split.exercises[index]
                if exercise.name == "Seated calf raise", exercise.loadMode == .platesPerSide,
                   exercise.equipmentNote == "Machine base resistance excluded" {
                    split.exercises[index].loadMode = .weightLoaded
                    split.exercises[index].equipmentNote = calfRaiseNote
                    changed = true
                }
            }
            return split
        }
        return changed ? upgraded : nil
    }
}

struct LiftSetRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var reps: Int
    /// Interpreted using the owning exercise's `loadMode`. For plates-per-side this is one side,
    /// never an invented bar, sled or machine total.
    var load: Double
    var completedAt: Date

    init(id: UUID = UUID(), reps: Int, load: Double, completedAt: Date = Date()) {
        self.id = id
        self.reps = reps
        self.load = load
        self.completedAt = completedAt
    }
}

struct LiftExerciseRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var loadMode: LiftLoadMode
    /// Optional human context such as "Gym A plate-loaded machine". It is not converted into load.
    var equipmentNote: String
    var sets: [LiftSetRecord]
    /// The split exercise this one came from or was added to, so the split and the open workout
    /// stay in step. Nil for an exercise with no split, and in workouts logged before this existed.
    var splitExerciseID: UUID?

    init(id: UUID = UUID(), name: String, loadMode: LiftLoadMode = .platesPerSide,
         equipmentNote: String = "", sets: [LiftSetRecord] = [], splitExerciseID: UUID? = nil) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.loadMode = loadMode
        self.equipmentNote = equipmentNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sets = sets
        self.splitExerciseID = splitExerciseID
    }

    var latestSet: LiftSetRecord? { sets.last }
}

/// One calendar month of finished workouts. `id` is `yyyy-MM`; `month` is its first instant, for
/// titles.
struct LiftHistoryMonth: Identifiable, Equatable {
    let id: String
    let month: Date
    var workouts: [LiftWorkoutSession]
}

struct LiftWorkoutSession: Identifiable, Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var exercises: [LiftExerciseRecord]
    var notes: String
    /// The split it was started from, kept as text so renaming or deleting the split later never
    /// rewrites history. Nil for an empty workout and for workouts logged before splits existed.
    var splitName: String?
    /// The split it was started from, so editing that split updates the open workout and adding an
    /// exercise to the workout adds it to the split. Nil for an empty workout and older workouts.
    var splitID: UUID?
    /// Split exercises taken off today's workout only, so keeping the workout in step with the
    /// split does not bring them back.
    var skippedSplitExercises: [UUID]?

    init(id: UUID = UUID(), startedAt: Date = Date(), endedAt: Date? = nil,
         exercises: [LiftExerciseRecord] = [], notes: String = "", splitName: String? = nil,
         splitID: UUID? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercises = exercises
        self.notes = notes
        self.splitName = splitName
        self.splitID = splitID
    }

    var isActive: Bool { endedAt == nil }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    /// How long a workout can sit with nothing logged before Lift Log asks whether it is finished.
    static let inactivityReminderDelay: TimeInterval = 60 * 60

    /// When the latest set was logged, or when the workout started if nothing has been.
    var lastActivity: Date {
        exercises.flatMap(\.sets).map(\.completedAt).reduce(startedAt, max)
    }

    /// When to ask whether this workout is finished: an hour after `activity`, the last time
    /// anything was logged. If that hour has already passed (the app was reopened later), an hour
    /// from `now`, so the question still comes once instead of never. Nil for a finished workout.
    func inactivityReminder(after activity: Date, now: Date) -> Date? {
        guard isActive else { return nil }
        let due = activity.addingTimeInterval(Self.inactivityReminderDelay)
        return due > now ? due : now.addingTimeInterval(Self.inactivityReminderDelay)
    }

    /// Finished workouts grouped into calendar months, newest month and newest workout first. An
    /// active workout is not history and is left out.
    static func byMonth(_ workouts: [LiftWorkoutSession],
                        calendar: Calendar = .current) -> [LiftHistoryMonth] {
        let finished = workouts.filter { !$0.isActive }
        let groups = Dictionary(grouping: finished) { workout -> DateComponents in
            calendar.dateComponents([.year, .month], from: workout.startedAt)
        }
        return groups.compactMap { parts, values -> LiftHistoryMonth? in
            guard let year = parts.year, let month = parts.month,
                  let start = calendar.date(from: DateComponents(year: year, month: month, day: 1))
            else { return nil }
            return LiftHistoryMonth(id: String(format: "%04d-%02d", year, month), month: start,
                                    workouts: values.sorted { $0.startedAt > $1.startedAt })
        }
        .sorted { $0.id > $1.id }
    }

    mutating func addExercise(name: String, loadMode: LiftLoadMode,
                              equipmentNote: String = "", splitExerciseID: UUID? = nil) throws -> UUID {
        let exercise = LiftExerciseRecord(name: name, loadMode: loadMode,
                                          equipmentNote: equipmentNote, splitExerciseID: splitExerciseID)
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard !exercise.name.isEmpty else { throw LiftLogError.emptyExerciseName }
        exercises.append(exercise)
        return exercise.id
    }

    mutating func addSet(exerciseID: UUID, reps: Int, load: Double,
                         completedAt: Date = Date()) throws {
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard reps > 0 else { throw LiftLogError.invalidReps }
        guard load.isFinite, load >= 0 else { throw LiftLogError.invalidLoad }
        guard var index = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            throw LiftLogError.exerciseNotFound
        }
        if exercises[index].sets.isEmpty {
            // Its first set: it joins the exercises already done, in the order they were done, so
            // the third exercise you do sits third whatever its place in the split.
            let done = exercises.filter { !$0.sets.isEmpty }.count
            let exercise = exercises.remove(at: index)
            index = min(done, exercises.count)
            exercises.insert(exercise, at: index)
        }
        exercises[index].sets.append(LiftSetRecord(reps: reps, load: load,
                                                    completedAt: completedAt))
    }

    /// Takes an exercise, and any sets logged for it, off the open workout.
    @discardableResult
    mutating func removeExercise(_ exerciseID: UUID) throws -> LiftExerciseRecord {
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            throw LiftLogError.exerciseNotFound
        }
        return exercises.remove(at: index)
    }

    /// Moves exercises as a list drag does: `offsets` are taken out and put back before
    /// `destination`, counted in the order before the move.
    mutating func moveExercises(from offsets: IndexSet, to destination: Int) throws {
        guard isActive else { throw LiftLogError.finishedWorkout }
        let valid = offsets.filter { exercises.indices.contains($0) }
        let moving = valid.map { exercises[$0] }
        let target = destination - valid.filter { $0 < destination }.count
        for offset in valid.sorted(by: >) { exercises.remove(at: offset) }
        exercises.insert(contentsOf: moving, at: min(max(0, target), exercises.count))
    }

    mutating func removeSet(exerciseID: UUID, setID: UUID) throws {
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            throw LiftLogError.exerciseNotFound
        }
        guard let setIndex = exercises[index].sets.firstIndex(where: { $0.id == setID }) else {
            throw LiftLogError.setNotFound
        }
        exercises[index].sets.remove(at: setIndex)
    }

    /// Brings the open workout in step with its split after the split was edited: exercises added
    /// to the split join the end of the workout, ones removed from it go unless sets were logged
    /// (those stay, no longer linked), renamed or changed ones update while nothing is logged on
    /// them, and the exercises not started yet follow the split's order. Ones taken off today only
    /// stay off. Exercises from before links existed are matched to the split by name.
    mutating func sync(with split: LiftSplit) {
        guard isActive else { return }
        splitID = split.id
        splitName = split.name
        let skipped = Set(skippedSplitExercises ?? [])
        for index in exercises.indices where exercises[index].splitExerciseID == nil {
            let taken = Set(exercises.compactMap(\.splitExerciseID))
            if let match = split.exercises.first(where: {
                !taken.contains($0.id) && LiftSplit.sameName($0.name, exercises[index].name)
            }) {
                exercises[index].splitExerciseID = match.id
            }
        }
        exercises = exercises.compactMap { record in
            guard let link = record.splitExerciseID else { return record }
            var updated = record
            guard let source = split.exercises.first(where: { $0.id == link }) else {
                if record.sets.isEmpty { return nil }
                updated.splitExerciseID = nil
                return updated
            }
            if record.sets.isEmpty {
                updated.name = source.name
                updated.loadMode = source.loadMode
                updated.equipmentNote = source.equipmentNote
            }
            return updated
        }
        let linked = Set(exercises.compactMap(\.splitExerciseID))
        for source in split.exercises where !linked.contains(source.id) && !skipped.contains(source.id) {
            exercises.append(LiftExerciseRecord(name: source.name, loadMode: source.loadMode,
                                                equipmentNote: source.equipmentNote,
                                                splitExerciseID: source.id))
        }
        let order = Dictionary(uniqueKeysWithValues: split.exercises.enumerated().map { ($1.id, $0) })
        let slots = exercises.indices.filter { index in
            exercises[index].sets.isEmpty && exercises[index].splitExerciseID.flatMap { order[$0] } != nil
        }
        let arranged = slots.map { exercises[$0] }.sorted {
            order[$0.splitExerciseID!]! < order[$1.splitExerciseID!]!
        }
        for (slot, record) in zip(slots, arranged) { exercises[slot] = record }
        let remaining = skipped.intersection(split.exercises.map(\.id))
        skippedSplitExercises = remaining.isEmpty ? nil : Array(remaining)
    }

    mutating func updateSet(exerciseID: UUID, setID: UUID, reps: Int, load: Double) throws {
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard reps > 0 else { throw LiftLogError.invalidReps }
        guard load.isFinite, load >= 0 else { throw LiftLogError.invalidLoad }
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            throw LiftLogError.exerciseNotFound
        }
        guard let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setID }) else {
            throw LiftLogError.setNotFound
        }
        exercises[exerciseIndex].sets[setIndex].reps = reps
        exercises[exerciseIndex].sets[setIndex].load = load
    }

    @discardableResult
    mutating func removeLastSet(exerciseID: UUID) throws -> LiftSetRecord {
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            throw LiftLogError.exerciseNotFound
        }
        guard let removed = exercises[index].sets.popLast() else { throw LiftLogError.setNotFound }
        return removed
    }

    /// Finishes a workout that was left open, ending it when its last set was logged rather than
    /// whenever the reminder was answered, so a forgotten workout does not record an extra hour.
    mutating func finishForgotten() throws {
        try finish(at: lastActivity)
    }

    mutating func finish(at date: Date = Date()) throws {
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard setCount > 0 else { throw LiftLogError.emptyWorkout }
        exercises.removeAll { $0.sets.isEmpty }
        endedAt = max(date, startedAt)
    }

    func validated() throws -> LiftWorkoutSession {
        guard startedAt.timeIntervalSince1970.isFinite else { throw LiftLogError.invalidDate }
        if let endedAt {
            guard endedAt.timeIntervalSince1970.isFinite, endedAt >= startedAt else {
                throw LiftLogError.invalidDate
            }
        }
        guard Set(exercises.map(\.id)).count == exercises.count else {
            throw LiftLogError.duplicateIdentifier
        }
        for exercise in exercises {
            guard !exercise.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LiftLogError.emptyExerciseName
            }
            guard Set(exercise.sets.map(\.id)).count == exercise.sets.count else {
                throw LiftLogError.duplicateIdentifier
            }
            for set in exercise.sets {
                guard set.reps > 0 else { throw LiftLogError.invalidReps }
                guard set.load.isFinite, set.load >= 0 else { throw LiftLogError.invalidLoad }
                guard set.completedAt.timeIntervalSince1970.isFinite else {
                    throw LiftLogError.invalidDate
                }
            }
        }
        return self
    }
}

enum LiftLogError: LocalizedError, Equatable {
    case emptyExerciseName
    case invalidReps
    case invalidLoad
    case invalidDate
    case exerciseNotFound
    case setNotFound
    case finishedWorkout
    case emptyWorkout
    case activeWorkoutExists
    case duplicateIdentifier
    case duplicateActiveWorkout
    case emptySplitName
    case duplicateSplitName
    case splitTooLarge

    var errorDescription: String? {
        switch self {
        case .emptyExerciseName: return "Enter an exercise name."
        case .invalidReps: return "Repetitions must be greater than zero."
        case .invalidLoad: return "Weight must be zero or greater."
        case .invalidDate: return "The workout contains an invalid date."
        case .exerciseNotFound: return "That exercise is no longer in this workout."
        case .setNotFound: return "There is no set to remove."
        case .finishedWorkout: return "This workout is already finished."
        case .emptyWorkout: return "Log at least one set before finishing the workout."
        case .activeWorkoutExists: return "Finish or discard the active workout first."
        case .duplicateIdentifier: return "The workout contains duplicate records."
        case .duplicateActiveWorkout: return "Only one workout can be active at a time."
        case .emptySplitName: return "Give the split a name."
        case .duplicateSplitName: return "Another split already has that name."
        case .splitTooLarge: return "Keep a split name under 40 characters, at most 40 exercises a split and 20 splits."
        }
    }
}

struct LiftLogBackup: Codable, Equatable {
    static let currentVersion = 1
    var version: Int
    var exportedAt: Date
    var workouts: [LiftWorkoutSession]
    /// Optional, so backups made before splits existed still read; they leave the splits alone.
    var splits: [LiftSplit]?

    init(exportedAt: Date = Date(), workouts: [LiftWorkoutSession], splits: [LiftSplit]? = nil) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.workouts = workouts
        self.splits = splits
    }

    func validatedSplits() throws -> [LiftSplit]? {
        try splits.map(LiftSplit.validatedList)
    }

    func validatedWorkouts() throws -> [LiftWorkoutSession] {
        guard version == Self.currentVersion else {
            throw CocoaError(.fileReadUnknown)
        }
        guard Set(workouts.map(\.id)).count == workouts.count else {
            throw LiftLogError.duplicateIdentifier
        }
        let checked = try workouts.map { try $0.validated() }
        guard checked.filter(\.isActive).count <= 1 else {
            throw LiftLogError.duplicateActiveWorkout
        }
        return checked.sorted { $0.startedAt > $1.startedAt }
    }
}
