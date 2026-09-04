import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Chicago")!
func date(_ day: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 12))!
}
func session(_ day: Int, count: Int, goal: Int? = 2) -> SquatSession {
    var value = SquatSession(day: SquatSession.dayKey(date(day), calendar: calendar),
                            started: date(day), interval: 45, goal: goal)
    for _ in 0..<count { value.log(SquatEvent(date: date(day), kind: .done)) }
    return value
}
var value = session(1, count: 0)
let event = SquatEvent(date: date(1), kind: .done)
value.log(event)
value.log(event)
assert(value.count == 1, "Duplicate event must count once")
value.undo()
assert(value.count == 0, "Undo removes one completion")
value.state = .ended
value.log(event)
assert(value.count == 0, "Ended sessions reject completion")
let encoded = try JSONEncoder().encode(value)
let decoded = try JSONDecoder().decode(SquatSession.self, from: encoded)
assert(decoded == value, "Persistence round trip")
var history = [session(1, count: 2), session(2, count: 2)]
assert(SquatSession.streaks(history, now: date(3), calendar: calendar).current == 2, "Today below goal stays at risk")
assert(SquatSession.streaks(history, now: date(4), calendar: calendar).current == 0, "Skipped day breaks streak")
history.append(session(3, count: 1))
assert(SquatSession.streaks(history, now: date(3), calendar: calendar).current == 2)
history.append(session(3, count: 1))
assert(SquatSession.streaks(history, now: date(3), calendar: calendar).current == 3, "Same day sessions aggregate once")
assert(SquatSession.streaks(history, now: date(5), calendar: calendar).best == 3)
assert(SquatSession.streaks([session(1, count: 50, goal: nil)], now: date(1), calendar: calendar).best == 0, "No implicit goal")
history[0].undo()
assert(SquatSession.streaks(history, now: date(3), calendar: calendar).best == 2, "Undo recomputes streak")
let dst = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 12))!
let prior = calendar.date(byAdding: .day, value: -1, to: dst)!
var a = session(1, count: 2); a.day = SquatSession.dayKey(prior, calendar: calendar); a.started = prior
var b = session(2, count: 2); b.day = SquatSession.dayKey(dst, calendar: calendar); b.started = dst
assert(SquatSession.streaks([a, b], now: dst, calendar: calendar).current == 2, "Calendar days, not 86400-second arithmetic")
print("PASS: 12 domain assertions (events, persistence, goal, streak, skipped day, DST)")

var actionSession = session(4, count: 0)
actionSession.state = .running
let done = SquatAction(id: "delivery-1", sessionID: actionSession.id, kind: .done,
                      date: date(4), day: actionSession.day, source: "notification")
actionSession = done.applying(to: actionSession)
assert(done.applying(to: actionSession).count == 1, "Duplicate notification counts once")
actionSession.undo()
assert(done.applying(to: actionSession).count == 0, "Undo must preserve the delivery receipt")
let restoredActionSession = try JSONDecoder().decode(SquatSession.self, from: JSONEncoder().encode(actionSession))
assert(done.applying(to: restoredActionSession).count == 0, "Receipt survives serialization")
let pause = SquatAction(id: "pause-1", sessionID: actionSession.id, kind: .pause,
                       date: date(4), day: actionSession.day, source: "notification")
actionSession = pause.applying(to: actionSession)
assert(actionSession.state == .paused && actionSession.pauseReason == "notification", "Pause retains deliberate source")
assert(pause.applying(to: actionSession) == actionSession, "Pause replay is idempotent")
var expiredDay = done
expiredDay.id = "tomorrow"
expiredDay.day = "2026-09-05"
assert(!expiredDay.canApply(to: actionSession), "A prior-day notification cannot log today's set")
var foreign = done
foreign.sessionID = UUID()
assert(!foreign.canApply(to: actionSession), "Wrong session cannot be changed")
let firstDelivery = SquatAction.notificationID(session: actionSession.id, request: "regular", delivered: date(4), action: "done")
let secondDelivery = SquatAction.notificationID(session: actionSession.id, request: "regular", delivered: date(4).addingTimeInterval(2700), action: "done")
assert(firstDelivery != secondDelivery, "Repeating deliveries must not share an action receipt")
print("PASS: 8 notification action assertions (replay, Undo, persistence, pause source, stale day, delivery identity)")
