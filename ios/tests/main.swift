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
