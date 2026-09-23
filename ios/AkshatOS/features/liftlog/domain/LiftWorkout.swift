import Foundation

enum LiftLoadMode: String, Codable, CaseIterable, Identifiable {
    case platesPerSide
    case perHand
    case stack
    case addedWeight
    case total

    var id: String { rawValue }

    var title: String {
        switch self {
        case .platesPerSide: return "Plates per side"
        case .perHand: return "Weight per hand"
        case .stack: return "Stack setting"
        case .addedWeight: return "Added weight"
        case .total: return "Total weight"
        }
    }

    var shortUnit: String {
        switch self {
        case .platesPerSide: return "lb/side"
        case .perHand: return "lb/hand"
        case .stack: return "lb stack"
        case .addedWeight: return "lb added"
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
        case .total:
            return "Example: a 45 lb bar plus 25 lb per side is 95 lb total → enter 95."
        }
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

    init(id: UUID = UUID(), name: String, loadMode: LiftLoadMode = .platesPerSide,
         equipmentNote: String = "", sets: [LiftSetRecord] = []) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.loadMode = loadMode
        self.equipmentNote = equipmentNote.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sets = sets
    }

    var latestSet: LiftSetRecord? { sets.last }
}

struct LiftWorkoutSession: Identifiable, Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var exercises: [LiftExerciseRecord]
    var notes: String

    init(id: UUID = UUID(), startedAt: Date = Date(), endedAt: Date? = nil,
         exercises: [LiftExerciseRecord] = [], notes: String = "") {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercises = exercises
        self.notes = notes
    }

    var isActive: Bool { endedAt == nil }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }

    mutating func addExercise(name: String, loadMode: LiftLoadMode,
                              equipmentNote: String = "") throws -> UUID {
        let exercise = LiftExerciseRecord(name: name, loadMode: loadMode,
                                          equipmentNote: equipmentNote)
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
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else {
            throw LiftLogError.exerciseNotFound
        }
        exercises[index].sets.append(LiftSetRecord(reps: reps, load: load,
                                                    completedAt: completedAt))
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

    mutating func finish(at date: Date = Date()) throws {
        guard isActive else { throw LiftLogError.finishedWorkout }
        guard setCount > 0 else { throw LiftLogError.emptyWorkout }
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
        }
    }
}

struct LiftLogBackup: Codable, Equatable {
    static let currentVersion = 1
    var version: Int
    var exportedAt: Date
    var workouts: [LiftWorkoutSession]

    init(exportedAt: Date = Date(), workouts: [LiftWorkoutSession]) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.workouts = workouts
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
