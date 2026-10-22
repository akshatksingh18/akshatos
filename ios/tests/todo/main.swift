import Foundation
var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
let clock = ActivityDayClock(calendar: cal)
let now = ISO8601DateFormatter().date(from: "2026-10-15T02:59:00Z")!
precondition(clock.key(now) == "2026-10-14")
precondition(clock.key(now.addingTimeInterval(60)) == "2026-10-15")
precondition(clock.date("2026-02-30") == nil)
var state = TodoState()
var task = TodoItem(title: "Read", due: now.addingTimeInterval(-86400)); task.repeatRule = "daily"
state.tasks = [task]
try state.select(task.id, for: clock.key(now), clock: clock)
let child = try state.complete(task.id, at: now, clock: clock)
precondition(child != nil && state.tasks.count == 2)
precondition(state.plans[0].qualifies)
precondition(state.tasks.last!.due! > now)
_ = try state.complete(task.id, at: now, clock: clock)
precondition(state.tasks.count == 2, "Completion replay must not create repeat duplicates")
let parsed = QuickTask.parse("Practice SQL Tuesday 5pm", now: now, calendar: cal)
precondition(parsed.title == "Practice SQL" && parsed.hasTime)
precondition(cal.component(.weekday, from: parsed.due!) == 3)
precondition(QuickTask.parse("A tomorrowland note", now: now, calendar: cal).due == nil)
var broken = state; broken.plans[0].selected.append(UUID())
do { _ = try broken.validated(); fatalError("Unknown priority id accepted") } catch {}
precondition(!PriorityPlan(day: "2026-10-15", zone: "UTC").qualifies)
print("To-do: day boundaries, atomic repeats, replay, parsing and priority validation passed")

// Routines have calendar-day instances, independent of whether yesterday was completed.
let morning = ISO8601DateFormatter().date(from: "2026-10-15T08:00:00Z")!
var routine = DailyRoutine(items: [RoutineItem(title: "Synthetic reading", targetMinute: 510)])
routine.prepare(at: morning, clock: clock)
let routineID = routine.items[0].id
try routine.record(routineID, status: .done, day: "2026-10-15", at: morning, clock: clock)
try routine.record(routineID, status: .done, day: "2026-10-15", at: morning.addingTimeInterval(60), clock: clock)
precondition(routine.days[0].checks[0].recordedAt == morning, "Replay cannot move a check-off timestamp")
routine.items[0].title = "Revised reading"
routine.prepare(at: morning.addingTimeInterval(120), clock: clock)
precondition(routine.days[0].checks[0].title == "Synthetic reading", "Finished snapshot must keep its wording")
let tomorrow = cal.date(byAdding: .day, value: 1, to: morning)!
routine.prepare(at: tomorrow, clock: clock)
precondition(routine.days.count == 2 && routine.days[1].done == 0)
precondition(routine.days[1].checks[0].title == "Revised reading")
try routine.record(routineID, status: .skipped, day: "2026-10-16", at: tomorrow, clock: clock)
precondition(routine.days[1].done == 0 && routine.days[1].skipped == 1)
try routine.record(routineID, status: .pending, day: "2026-10-16", at: tomorrow, clock: clock)
precondition(routine.days[1].checks[0].recordedAt == nil)
do { try routine.record(routineID, status: .done, day: "2026-10-15", at: tomorrow, clock: clock); fatalError("Stale yesterday tap accepted") } catch {}
routine.items[0].paused = true
routine.prepare(at: tomorrow, clock: clock)
precondition(routine.days[1].checks.isEmpty && routine.days[0].done == 1)
routine.items[0].paused = false
routine.items[0].weekdays = [2] // Thursday is not Monday.
routine.prepare(at: morning, clock: clock)
precondition(routine.days[0].done == 1, "A changed schedule cannot erase a recorded completion")
let beforeBoundary = ISO8601DateFormatter().date(from: "2026-10-17T02:59:00Z")!
var boundary = DailyRoutine(items: [RoutineItem(title: "Synthetic task")])
boundary.prepare(at: beforeBoundary, clock: clock)
boundary.prepare(at: beforeBoundary.addingTimeInterval(60), clock: clock)
precondition(boundary.days.map(\.day) == ["2026-10-16", "2026-10-17"])
var dstCal = Calendar(identifier: .gregorian); dstCal.timeZone = TimeZone(identifier: "America/Chicago")!
let dstClock = ActivityDayClock(calendar: dstCal)
var dst = DailyRoutine(items: [RoutineItem(title: "Synthetic daily action")])
let fall = ISO8601DateFormatter().date(from: "2026-11-01T06:30:00Z")!
dst.prepare(at: fall, clock: dstClock); dst.prepare(at: fall.addingTimeInterval(3600), clock: dstClock)
precondition(dst.days.count == 1, "Repeated DST hour must not create another checklist")
// Missing optional field in a legacy snapshot must decode without replacing its tasks.
let oldJSON = Data(#"{"version":1,"tasks":[],"thoughts":[],"plans":[],"areas":["Personal"]}"#.utf8)
let legacyRoutineState = try LocalDataCoding.decode(TodoState.self, oldJSON).validated()
precondition(legacyRoutineState.routine == nil)
var withRoutine = TodoState(); withRoutine.routine = boundary
let decodedRoutine = try LocalDataCoding.decode(TodoState.self, LocalDataCoding.encode(withRoutine)).validated()
precondition(decodedRoutine.routine == boundary)
var invalidRoutine = boundary; invalidRoutine.items[0].targetMinute = 1440
do { _ = try invalidRoutine.validated(); fatalError("Invalid target minute accepted") } catch {}
invalidRoutine = boundary; invalidRoutine.items[0].weekdays = []
do { _ = try invalidRoutine.validated(); fatalError("Empty weekday selection accepted") } catch {}
invalidRoutine = boundary; invalidRoutine.days.append(boundary.days[0])
do { _ = try invalidRoutine.validated(); fatalError("Duplicate routine day accepted") } catch {}
print("Daily routine: calendar instances, weekday/pause, immutable history, skip/replay, stale taps, DST and legacy backup checks passed")
