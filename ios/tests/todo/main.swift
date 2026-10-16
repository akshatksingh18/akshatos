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
var broken = state; broken.plans[0].selected.append(UUID())
do { _ = try broken.validated(); fatalError("Unknown priority id accepted") } catch {}
precondition(!PriorityPlan(day: "2026-10-15", zone: "UTC").qualifies)
print("To-do: day boundaries, atomic repeats, replay, parsing and priority validation passed")
