import Foundation

let now = Date(timeIntervalSince1970: 1_790_105_400)
var workout = LiftWorkoutSession(startedAt: now)
let squat = try workout.addExercise(name: "  Plate-loaded row  ", loadMode: .platesPerSide,
                                    equipmentNote: "  machine base unknown  ")
try workout.addSet(exerciseID: squat, reps: 9, load: 42.5, completedAt: now.addingTimeInterval(60))
try workout.addSet(exerciseID: squat, reps: 9, load: 42.5, completedAt: now.addingTimeInterval(120))
let skipped = try workout.addExercise(name: "Optional movement", loadMode: .stack)

assert(workout.exercises.first?.name == "Plate-loaded row", "Exercise names are trimmed")
assert(workout.exercises.first?.equipmentNote == "machine base unknown", "Notes are trimmed")
assert(workout.exercises.first?.loadMode == .platesPerSide, "Per-side measurement is preserved")
assert(workout.exercises.first?.latestSet?.load == 42.5, "The stored load is one side, not a fake total")
assert(workout.setCount == 2, "Every working set is counted")

let firstSet = workout.exercises[0].sets[0]
try workout.updateSet(exerciseID: squat, setID: firstSet.id, reps: 10, load: 45)
assert(workout.exercises[0].sets[0].reps == 10 && workout.exercises[0].sets[0].load == 45,
       "Editing a set preserves identity and changes only its performance")

let removed = try workout.removeLastSet(exerciseID: squat)
assert(removed.reps == 9 && workout.setCount == 1, "Undo removes only the last set")
try workout.finish(at: now.addingTimeInterval(600))
assert(!workout.isActive && workout.endedAt == now.addingTimeInterval(600), "Finishing closes the session")
assert(!workout.exercises.contains(where: { $0.id == skipped }),
       "Finishing removes unperformed template exercises from history")

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
let starting = LiftSplit.starting
assert(starting.map(\.name) == ["Lower day", "Back and biceps day", "Chest day"],
       "A new install starts with Lower and the old Upper day split in two")
assert(starting[0].exercises.map(\.name) == [
    "Smith-machine squat", "Barbell Romanian deadlift", "Leg press",
    "Seated machine leg curl", "Seated calf raise"
], "Lower day is unchanged")
assert(starting[1].exercises.map(\.name) == ["Weighted pull-ups", "Seated cable row", "Dumbbell biceps curl"])
assert(starting[2].exercises.map(\.name) == [
    "Dumbbell bench press", "Shoulder press", "Pec-deck fly", "Triceps pushdown"
])
assert(starting[1].exercises.first?.loadMode == .addedWeight)
assert(starting[0].exercises[3].loadMode == .stack)
assert((try? LiftSplit.validatedList(starting)) != nil, "The starting splits are valid")

// Splits: trimmed, named, unique by name ignoring case, bounded.
let trimmed = try! LiftSplit(name: "  Arms day ", exercises: [LiftSplitExercise(" Curl ", .perHand, equipmentNote: " EZ bar ")]).validated()
assert(trimmed.name == "Arms day" && trimmed.exercises[0].name == "Curl" && trimmed.exercises[0].equipmentNote == "EZ bar")
assert((try? LiftSplit(name: " ").validated()) == nil, "A split needs a name")
assert((try? LiftSplit(name: "Arms", exercises: [LiftSplitExercise("", .stack)]).validated()) == nil,
       "Every exercise in a split needs a name")
assert((try? LiftSplit(name: String(repeating: "x", count: 41)).validated()) == nil, "Names stay short")
assert((try? LiftSplit.validatedList(starting + [LiftSplit(name: "CHEST DAY")])) == nil,
       "Two splits cannot share a name, ignoring case")
assert((try? LiftSplit.validatedList((0..<21).map { LiftSplit(name: "Day \($0)") })) == nil, "At most 20 splits")
assert((try! LiftSplit.validatedList([])).isEmpty, "Deleting every split is allowed; empty workouts still work")

// A workout remembers its split's name; older records without one still read.
let named = LiftWorkoutSession(startedAt: Date(timeIntervalSince1970: 1_790_105_400), splitName: "Chest day")
let namedRoundTrip = try! JSONDecoder().decode(LiftWorkoutSession.self, from: try! JSONEncoder().encode(named))
assert(namedRoundTrip.splitName == "Chest day")
let olderWorkout = #"{"id":"6F1F8C1E-4C1E-4E8A-9C1A-111111111111","startedAt":0,"exercises":[],"notes":""}"#
assert((try! JSONDecoder().decode(LiftWorkoutSession.self, from: Data(olderWorkout.utf8))).splitName == nil,
       "A workout saved before splits existed has no split name")

// The backup carries splits when present and validates them.
let withSplits = LiftLogBackup(workouts: [], splits: starting)
assert((try! withSplits.validatedSplits())?.count == 3)
assert((try! LiftLogBackup(workouts: []).validatedSplits()) == nil, "An older backup has no splits to restore")
assert((try? LiftLogBackup(workouts: [], splits: [LiftSplit(name: "")]).validatedSplits()) == nil,
       "A backup with a bad split is refused")
print("PASS: Lift Log domain assertions (splits, per-side load, edit, finish, validation, backup)")

// History screen: finished workouts grouped by month, newest first, the active one left out.
var historyCalendar = Calendar(identifier: .gregorian)
historyCalendar.timeZone = TimeZone(identifier: "UTC")!
func historyWorkout(_ year: Int, _ month: Int, _ day: Int) -> LiftWorkoutSession {
    let start = historyCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 18))!
    return LiftWorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(3_600))
}
let historyEarly = historyWorkout(2026, 9, 5)
let historyLate = historyWorkout(2026, 9, 20)
let historyAugust = historyWorkout(2026, 8, 30)
let historyNewYear = historyWorkout(2027, 1, 2)
let historyActive = LiftWorkoutSession(startedAt: historyCalendar.date(
    from: DateComponents(year: 2027, month: 1, day: 3))!)
let liftMonths = LiftWorkoutSession.byMonth(
    [historyEarly, historyAugust, historyActive, historyNewYear, historyLate], calendar: historyCalendar)
assert(liftMonths.map(\.id) == ["2027-01", "2026-09", "2026-08"],
       "Months are newest first, across a year boundary")
assert(liftMonths[1].workouts.map(\.id) == [historyLate.id, historyEarly.id],
       "Workouts inside a month are newest first")
assert(!liftMonths.flatMap(\.workouts).contains { $0.id == historyActive.id },
       "The workout in progress is not history")
assert(liftMonths[2].month == historyCalendar.date(from: DateComponents(year: 2026, month: 8, day: 1)),
       "A month carries its first day for its title")
assert(liftMonths.flatMap(\.workouts).count == 4, "Every finished workout is reachable, not just recent ones")
assert(LiftWorkoutSession.byMonth([historyActive], calendar: historyCalendar).isEmpty,
       "A history holding only the active workout is empty")
print("PASS: 6 Lift Log history assertions (month order, year boundary, in-month order, active excluded, all reachable)")

// Seated calf raise: plates loaded on one post are entered as one number.
assert(LiftLoadMode.weightLoaded.title == "Weight loaded" && LiftLoadMode.weightLoaded.shortUnit == "lb loaded")
assert(LiftLoadMode.weightLoaded.example.contains("seated calf raise"))
assert(LiftLoadMode.allCases.map(\.rawValue).contains("weightLoaded"))
let startingCalf = LiftSplit.starting.flatMap(\.exercises).first { $0.name == "Seated calf raise" }
assert(startingCalf?.loadMode == .weightLoaded, "A new install enters the calf raise as weight loaded")
let oldCalf = LiftSplitExercise("Seated calf raise", .platesPerSide,
                                equipmentNote: "Machine base resistance excluded")
let ownCalf = LiftSplitExercise("Seated calf raise", .platesPerSide, equipmentNote: "Gym B machine")
let oldSplits = [LiftSplit(name: "Lower day", exercises: [oldCalf]),
                 LiftSplit(name: "Legs", exercises: [ownCalf])]
let upgradedSplits = LiftSplit.upgradingCalfRaise(oldSplits)
assert(upgradedSplits?[0].exercises[0].loadMode == .weightLoaded
       && upgradedSplits?[0].exercises[0].id == oldCalf.id,
       "The untouched starting calf raise moves to weight loaded and keeps its identity")
assert(upgradedSplits?[1].exercises[0] == ownCalf, "A calf raise Akshat set up himself is left alone")
assert(LiftSplit.upgradingCalfRaise(upgradedSplits!) == nil, "The upgrade happens once")
let calfJSON = try JSONEncoder().encode(LiftSplitExercise("Seated calf raise", .weightLoaded))
let calfDecoded = try JSONDecoder().decode(LiftSplitExercise.self, from: calfJSON)
assert(calfDecoded.loadMode == .weightLoaded, "Weight loaded survives a round trip")

// Forgotten workouts: a reminder an hour after the last thing logged, and finishing at the last set.
var idle = LiftWorkoutSession(startedAt: now)
assert(idle.lastActivity == now, "With nothing logged, activity is the start")
let idleLift = try idle.addExercise(name: "Leg press", loadMode: .platesPerSide)
try idle.addSet(exerciseID: idleLift, reps: 10, load: 90, completedAt: now.addingTimeInterval(600))
try idle.addSet(exerciseID: idleLift, reps: 10, load: 90, completedAt: now.addingTimeInterval(1_200))
assert(idle.lastActivity == now.addingTimeInterval(1_200), "Activity is the latest set")
assert(idle.inactivityReminder(after: idle.lastActivity, now: now.addingTimeInterval(1_300))
       == now.addingTimeInterval(1_200 + 3_600), "The reminder is an hour after the last set")
assert(idle.inactivityReminder(after: idle.lastActivity, now: now.addingTimeInterval(9_000))
       == now.addingTimeInterval(9_000 + 3_600), "Reopened after the hour, it asks an hour from now")
try idle.finishForgotten()
assert(idle.endedAt == now.addingTimeInterval(1_200), "A forgotten workout ends at its last set")
assert(idle.inactivityReminder(after: now, now: now) == nil, "A finished workout gets no reminder")
var idleEmpty = LiftWorkoutSession(startedAt: now)
do {
    try idleEmpty.finishForgotten()
    assertionFailure("A workout with no sets cannot be finished from the reminder")
} catch {
    assert(error as? LiftLogError == .emptyWorkout)
}
print("PASS: Lift Log weight-loaded and inactivity-reminder assertions")
