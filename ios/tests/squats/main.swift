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
let dstStart = calendar.startOfDay(for: dst)
let dstEnd = SquatSession.endOfDay(SquatSession.dayKey(dstStart, calendar: calendar), calendar: calendar)!
assert(dstEnd.timeIntervalSince(dstStart) == 90000, "Fall DST day closes at the next local midnight")
let spring = calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12))!
let springStart = calendar.startOfDay(for: spring)
let springEnd = SquatSession.endOfDay(SquatSession.dayKey(spring, calendar: calendar), calendar: calendar)!
assert(springEnd.timeIntervalSince(springStart) == 82800, "Spring DST day closes at the next local midnight")
let zoneInstant = ISO8601DateFormatter().date(from: "2026-09-05T23:30:00Z")!
var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(secondsFromGMT: 0)!
var tokyo = Calendar(identifier: .gregorian); tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
assert(SquatSession.dayKey(zoneInstant, calendar: utc) == "2026-09-05" &&
       SquatSession.dayKey(zoneInstant, calendar: tokyo) == "2026-09-06",
       "Day ownership follows the active local time zone")
let future = session(9, count: 2)
assert(SquatSession.streaks([future], now: date(4), calendar: calendar).best == 0,
       "A future clock-created day must not inflate the current best")
var firstGoal = session(4, count: 4, goal: 4)
firstGoal.started = date(4).addingTimeInterval(-3600)
var changedGoal = session(4, count: 0, goal: 8)
changedGoal.started = date(4)
assert(SquatSession.streaks([firstGoal, changedGoal], now: date(4), calendar: calendar).current == 1,
       "The first session snapshots the date goal")
let neutral = session(1, count: 20, goal: nil)
assert(SquatSession.streaks([neutral, session(3, count: 2)], now: date(4), calendar: calendar).current == 1,
       "Goal-free dates before activation are neutral")
print("PASS: 18 domain assertions (events, persistence, goal, streak, skipped day, clock, DST, time zone)")

let boundary = HomeBoundary(latitude: 41, longitude: -87, radius: 150)
assert(HomeBoundary.defaultRadius == 150, "The chosen Home radius defaults to 150 meters")
assert((try? HomeBoundary(latitude: 91, longitude: -87, radius: 150).validated()) == nil,
       "Invalid latitude is rejected")
assert((try? HomeBoundary(latitude: 41, longitude: -87, radius: 49).validated()) == nil,
       "A radius below the supported floor is rejected")
assert(boundary.matches(HomeBoundary(latitude: 41.0000005, longitude: -87.0000005, radius: 151)),
       "Equivalent monitored circles tolerate harmless system rounding")
var home = HomeAutomationState(boundary: boundary, presence: .inside)
let exit = HomeBoundaryEvent(kind: .exited, date: date(4),
                             regionIdentifier: HomeAutomationState.regionIdentifier)
assert(home.accept(exit, activeDay: "2026-09-04", activeState: .running,
                   pauseReason: nil, currentDay: "2026-09-04") == .pause,
       "Leaving Home pauses only a running day")
let duplicateExit = HomeBoundaryEvent(kind: .stateOutside, date: date(4).addingTimeInterval(30),
                                      regionIdentifier: HomeAutomationState.regionIdentifier)
assert(home.accept(duplicateExit, activeDay: "2026-09-04", activeState: .paused,
                   pauseReason: "homeAwayAutomation", currentDay: "2026-09-04") == .none,
       "Boundary jitter is debounced")
let entry = HomeBoundaryEvent(kind: .entered, date: date(4).addingTimeInterval(180),
                              regionIdentifier: HomeAutomationState.regionIdentifier)
assert(home.accept(entry, activeDay: "2026-09-04", activeState: .paused,
                   pauseReason: "homeAwayAutomation", currentDay: "2026-09-04") == .resume,
       "Arrival resumes the same day only after Home automation paused it")
var manual = HomeAutomationState(boundary: boundary, presence: .outside)
assert(manual.accept(entry, activeDay: "2026-09-04", activeState: .paused,
                     pauseReason: "dashboard", currentDay: "2026-09-04") == .none,
       "Arrival cannot override a deliberate pause")
var priorDay = HomeAutomationState(boundary: boundary, presence: .outside)
assert(priorDay.accept(entry, activeDay: "2026-09-03", activeState: .paused,
                       pauseReason: "homeAwayAutomation", currentDay: "2026-09-04") == .none,
       "Arrival cannot revive a prior day")
print("PASS: 9 Home automation assertions (defaults, validation, matching, pause, debounce, reason, same-day resume)")

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
var pausedActionSession = actionSession
pausedActionSession.state = .paused
let pausedDone = SquatAction(id: "paused-done", sessionID: pausedActionSession.id, kind: .done,
                             date: date(4), day: pausedActionSession.day, source: "dashboard")
assert(pausedDone.applying(to: pausedActionSession).count == 1,
       "An explicit completed set remains valid while reminders are paused")
pausedActionSession.state = .ended
assert(pausedDone.applying(to: pausedActionSession).count == 0,
       "An ended session rejects late completed-set actions")
print("PASS: 10 notification action assertions (replay, Undo, persistence, paused Done, pause source, stale day, delivery identity)")

var morning = session(4, count: 0, goal: 3)
morning.started = date(4).addingTimeInterval(-7200)
morning.log(SquatEvent(date: morning.started.addingTimeInterval(600), kind: .done))
morning.log(SquatEvent(date: morning.started.addingTimeInterval(1200), kind: .pause))
morning.log(SquatEvent(date: morning.started.addingTimeInterval(1800), kind: .resume))
morning.state = .ended
morning.ended = date(4).addingTimeInterval(-3600)
var afternoon = session(4, count: 0, goal: 3)
afternoon.id = UUID()
afternoon.started = date(4).addingTimeInterval(-1800)
afternoon.log(SquatEvent(date: afternoon.started.addingTimeInterval(300), kind: .done))
afternoon.log(SquatEvent(date: afternoon.started.addingTimeInterval(900), kind: .snooze))
afternoon.state = .ended
afternoon.ended = date(4)
let daily = SquatDaySummary.make(day: morning.day, sessions: [morning, afternoon], now: date(4), calendar: calendar)!
assert(daily.completedSets == 2 && daily.sessions.count == 2, "Daily history aggregates same-day sessions")
assert(daily.activeDuration == 4800 && daily.pausedDuration == 600, "Daily durations exclude paired pauses")
assert(daily.pauseSegments.count == 1 && daily.snoozeTimes.count == 1, "Daily timeline retains pauses and snoozes")
assert(daily.goalStatus == .atRisk, "Current incomplete goal is at risk")
let laterDaily = SquatDaySummary.make(day: morning.day, sessions: [morning, afternoon], now: date(5), calendar: calendar)!
assert(laterDaily.goalStatus == .missed, "Past incomplete goal is missed")

afternoon.actionReceipts = ["notification-receipt"]
let backup = SquatsBackup(createdAt: date(5), sessions: [morning, afternoon], interval: 30, goal: 3)
let restoredBackup = try SquatsBackup.decode(backup.encoded())
assert(restoredBackup == backup, "Backup round trip preserves history, settings and receipts")
var invalidBackup = backup
invalidBackup.sessions.append(afternoon)
assert((try? invalidBackup.validated()) == nil, "Duplicate session IDs invalidate the whole backup")
assert((try? SquatsBackup.decode(Data("not-json".utf8))) == nil, "Malformed backup is rejected")
var openPaused = session(5, count: 0, goal: 8)
openPaused.started = date(5).addingTimeInterval(-3_600)
openPaused.log(SquatEvent(date: date(5).addingTimeInterval(-1_800), kind: .pause))
openPaused.state = .paused
let openSummary = SquatDaySummary.make(day: openPaused.day, sessions: [openPaused],
                                       now: date(5), calendar: calendar)!
assert(openSummary.activeDuration == 1_800 && openSummary.pausedDuration == 1_800,
       "An open pause divides elapsed time without inventing an end date")
var secondActive = openPaused
secondActive.id = UUID()
let conflictingBackup = SquatsBackup(createdAt: date(5), sessions: [openPaused, secondActive],
                                     interval: 45, goal: 8)
assert((try? conflictingBackup.validated()) == nil, "A backup cannot restore two active sessions")
print("PASS: 10 history and recovery assertions (daily aggregation, durations, status, open pause, backup validation)")
