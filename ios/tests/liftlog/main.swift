import Foundation

let now = Date(timeIntervalSince1970: 1_790_105_400)
var workout = LiftWorkoutSession(startedAt: now)
let squat = try workout.addExercise(name: "  Plate-loaded row  ", loadMode: .platesPerSide,
                                    equipmentNote: "  machine base unknown  ")
try workout.addSet(exerciseID: squat, reps: 9, load: 42.5, completedAt: now.addingTimeInterval(60))
try workout.addSet(exerciseID: squat, reps: 9, load: 42.5, completedAt: now.addingTimeInterval(120))

assert(workout.exercises.first?.name == "Plate-loaded row", "Exercise names are trimmed")
assert(workout.exercises.first?.equipmentNote == "machine base unknown", "Notes are trimmed")
assert(workout.exercises.first?.loadMode == .platesPerSide, "Per-side measurement is preserved")
assert(workout.exercises.first?.latestSet?.load == 42.5, "The stored load is one side, not a fake total")
assert(workout.setCount == 2, "Every working set is counted")

let removed = try workout.removeLastSet(exerciseID: squat)
assert(removed.reps == 9 && workout.setCount == 1, "Undo removes only the last set")
try workout.finish(at: now.addingTimeInterval(600))
assert(!workout.isActive && workout.endedAt == now.addingTimeInterval(600), "Finishing closes the session")

do {
    try workout.addSet(exerciseID: squat, reps: 6, load: 57.5)
    assertionFailure("A finished workout must reject new sets")
} catch {
    assert(error as? LiftLogError == .finishedWorkout)
}

let encoded = try JSONEncoder().encode(workout)
let decoded = try JSONDecoder().decode(LiftWorkoutSession.self, from: encoded)
let checked = try decoded.validated()
assert(checked == workout, "A valid workout survives a domain round trip")

let backup = LiftLogBackup(exportedAt: now, workouts: [workout])
let restored = try backup.validatedWorkouts()
assert(restored == [workout], "A backup validates without changing its workouts")

var secondActive = LiftWorkoutSession(startedAt: now.addingTimeInterval(1_000))
_ = try secondActive.addExercise(name: "Chest-supported row", loadMode: .platesPerSide)
do {
    _ = try LiftLogBackup(workouts: [LiftWorkoutSession(startedAt: now), secondActive]).validatedWorkouts()
    assertionFailure("Two active workouts must be rejected")
} catch {
    assert(error as? LiftLogError == .duplicateActiveWorkout)
}

assert(LiftLoadMode.platesPerSide.shortUnit == "lb/side")
assert(LiftLoadMode.perHand.shortUnit == "lb/hand")
assert(LiftLoadMode.platesPerSide.guidance.contains("one side"))
assert(LiftLoadMode.perHand.example.contains("dumbbell bench"))
assert(LiftLoadMode.stack.guidance.contains("weight stack"))
assert(LiftLoadMode.stack.example.contains("seated cable row"))
assert(LiftLoadMode.addedWeight.guidance.contains("bodyweight"))
assert(LiftLoadMode.addedWeight.example.contains("weighted pull-ups"))
assert(LiftLoadMode.total.guidance.contains("complete known load"))
assert(LiftLoadMode.total.example.contains("95 lb total"))
print("PASS: Lift Log domain assertions (per-side load, sets, finish, validation, backup)")
