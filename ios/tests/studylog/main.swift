import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/Chicago")!
let clock = StudyDayClock(calendar: calendar)
func at(_ day: Int, _ hour: Int, _ minute: Int = 0, month: Int = 10) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}
let sixHours = 6 * 3600

// The study day starts at 3:00 AM, so a late session stays with the day it began.
assert(clock.key(for: at(14, 9)) == "2026-10-14")
assert(clock.key(for: at(15, 2, 59)) == "2026-10-14", "Before 3:00 AM still belongs to the previous day")
assert(clock.key(for: at(15, 3)) == "2026-10-15", "3:00 AM starts the next day")
assert(clock.key(for: at(1, 1, month: 11)) == "2026-10-31", "A month boundary before 3:00 AM stays in the old month")
assert(clock.start(of: "2026-10-15") == at(15, 3))
assert(clock.next("2026-10-31") == "2026-11-01" && clock.previous("2026-11-01") == "2026-10-31")
assert(clock.week(containing: "2026-10-14") == ["2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15",
                                                  "2026-10-16", "2026-10-17", "2026-10-18"],
       "Weeks run Monday to Sunday")
assert(clock.week(containing: "2026-10-18").first == "2026-10-12", "Sunday ends its week")
print("PASS: study day assertions (3:00 AM rollover, months, weeks)")

// Start and Pause: one running block, kept as timestamps.
var log = StudyLog()
let first = log.start(at: at(14, 9), target: sixHours)
assert(first != nil && log.running?.id == first?.id)
assert(log.start(at: at(14, 9, 1), target: sixHours) == nil, "A second Start while running changes nothing")
assert(log.studied(on: "2026-10-14", now: at(14, 10), clock: clock) == 3600,
       "A running block counts up to now, from its start time alone")
assert(log.pause(at: at(14, 10, 30))?.end == at(14, 10, 30))
assert(log.pause(at: at(14, 11)) == nil, "Pause when paused changes nothing")
assert(log.studied(on: "2026-10-14", now: at(14, 18), clock: clock) == 5400, "A paused day stops counting")
log.start(at: at(14, 12), target: sixHours)
assert(log.pause(at: at(14, 12).addingTimeInterval(3)) == nil, "A block under five seconds is an accidental tap")
assert(log.segments.count == 1, "and it is removed")
log.start(at: at(14, 10), target: sixHours)
assert(log.running?.start == at(14, 10, 30), "A Start with the clock set back never overlaps the last block")
log.pause(at: at(14, 11))
print("PASS: start/pause assertions (idempotent, timestamps, short taps, clock set back)")

// A block across 3:00 AM counts for both days.
var late = StudyLog()
late.start(at: at(14, 23), target: sixHours)
late.pause(at: at(15, 4))
let pieces = late.blocks(now: at(15, 12), clock: clock)
assert(pieces.map(\.day) == ["2026-10-14", "2026-10-15"])
assert(pieces.map(\.duration) == [4 * 3600, 3600], "Split exactly at 3:00 AM")
assert(late.studied(on: "2026-10-14", now: at(15, 12), clock: clock) == 4 * 3600)
// On the night clocks go back (1 November 2026 in Chicago), 1 AM happens twice; real time counts.
var fallBack = StudyLog()
fallBack.start(at: at(31, 23), target: sixHours)
fallBack.pause(at: at(1, 4, month: 11))
let fallPieces = fallBack.blocks(now: at(1, 12, month: 11), clock: clock)
assert(fallPieces.map(\.day) == ["2026-10-31", "2026-11-01"])
assert(fallPieces.map(\.duration) == [5 * 3600, 3600], "The repeated hour is counted once, as real time")
print("PASS: rollover assertions (split at 3:00 AM, daylight saving)")

// Days, targets and history.
var history = StudyLog()
history.start(at: at(13, 9), target: sixHours)
history.pause(at: at(13, 11))
history.start(at: at(14, 9), target: 4 * 3600)
history.pause(at: at(14, 9, 30))
history.start(at: at(14, 14), target: sixHours)
let days = history.days(now: at(14, 15), clock: clock, fallbackTarget: 5 * 3600)
assert(days.map(\.day) == ["2026-10-14", "2026-10-13"], "Newest day first")
assert(days.first?.studied == 1800 + 3600, "A running block is part of today")
assert(days.first?.blocks.last?.isRunning == true)
assert(days.first?.target == 4 * 3600, "A day keeps the target its first block recorded")
assert(history.target(for: "2026-10-12", clock: clock) == nil, "A day without study has no recorded target")
print("PASS: history assertions (days, running block, per-day target)")

// Whole-set checks before saving or restoring.
let a = StudySegment(start: at(14, 9), end: at(14, 10), dayTarget: sixHours)
let b = StudySegment(start: at(14, 9, 30), end: at(14, 11), dayTarget: sixHours)
let open1 = StudySegment(start: at(14, 12), dayTarget: sixHours)
let open2 = StudySegment(start: at(14, 13), dayTarget: sixHours)
func refuses(_ segments: [StudySegment], _ expected: StudyLogError) -> Bool {
    do { _ = try StudyLog.validated(segments); return false } catch { return (error as? StudyLogError) == expected }
}
assert(refuses([a, b], .overlappingSegments))
assert(refuses([a, open1, open2], .moreThanOneRunning))
assert(refuses([open1, StudySegment(start: at(14, 13), end: at(14, 14), dayTarget: sixHours)], .overlappingSegments),
       "A running block must be the latest")
assert(refuses([StudySegment(start: at(14, 10), end: at(14, 9), dayTarget: sixHours)], .invalidSegment))
assert(refuses([a, a], .duplicateIdentifier))
let checked = try StudyLog.validated([open1, a])
assert(checked.map(\.id) == [a.id, open1.id], "Valid blocks come back in time order")
var future = StudyLogBackup(exportedAt: at(14, 12), segments: [a], settings: .standard)
future.version = 99
assert((try? future.validatedSegments()) == nil, "A newer backup is refused")
let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601
let roundTrip = try decoder.decode(StudyLogBackup.self,
                                   from: try encoder.encode(StudyLogBackup(exportedAt: at(14, 12), segments: [a, open1],
                                                                           settings: .standard)))
let roundTripSegments = try roundTrip.validatedSegments()
assert(roundTripSegments.count == 2 && roundTrip.settings == .standard)
print("PASS: validation assertions (overlap, running, order, duplicates, versions, round trip)")

// Settings and wording.
assert(StudySettings(target: 60, floor: 9_999, goal: 99_999).validated()
       == StudySettings(target: 1800, floor: 1800, goal: 1800), "Marks stay inside a sensible target")
assert(StudySettings.standard.validated() == StudySettings(target: sixHours, floor: 2 * 3600, goal: 4 * 3600))
assert(StudyTime.clock(6 * 3600) == "6:00:00")
assert(StudyTime.clock(5 * 3600 + 42 * 60 + 10.9) == "5:42:10")
assert(StudyTime.clock(-5) == "0:00:00")
assert(StudyTime.short(45 * 60) == "45 m" && StudyTime.short(2 * 3600) == "2 h" && StudyTime.short(8100) == "2 h 15 m")
assert(StudyTime.hours(4 * 3600) == "4 h" && StudyTime.hours(16_200) == "4.5 h")
print("PASS: settings and wording assertions")

// Cross-platform exchange uses the same synthetic golden files as the Windows writer tests.
let fixtureRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("windows/tests/fixtures")
let exchangeDecoder = JSONDecoder(); exchangeDecoder.dateDecodingStrategy = .iso8601
let exchangeNow = ISO8601DateFormatter().date(from: "2026-10-20T18:00:00Z")!
let laptopWire = try exchangeDecoder.decode(StudyExchange.self, from: Data(contentsOf: fixtureRoot.appendingPathComponent("laptop-wire.json")))
let mergedLaptop = try laptopWire.merged(into: [], now: exchangeNow)
assert(mergedLaptop.count == 1 && mergedLaptop[0].exchangeOriginID == laptopWire.sourceID)
assert(mergedLaptop[0].duration(now: exchangeNow) == 1800)
let replayedLaptop = try laptopWire.merged(into: mergedLaptop, now: exchangeNow)
assert(replayedLaptop.count == 1, "Replay must not add hours")
var staleWire = laptopWire; staleWire.revision = 0
assert((try? staleWire.merged(into: mergedLaptop, now: exchangeNow)) == nil)
var changedWire = laptopWire; changedWire.sessions[0].end.addTimeInterval(60)
assert((try? changedWire.merged(into: mergedLaptop, now: exchangeNow)) == nil)
let overlap = StudySegment(start: laptopWire.sessions[0].start, end: laptopWire.sessions[0].end, dayTarget: sixHours)
assert((try? laptopWire.merged(into: [overlap], now: exchangeNow)) == nil, "Overlap never adds time")
let runningExchangeOverlap = StudySegment(start: laptopWire.sessions[0].start, dayTarget: sixHours)
assert((try? laptopWire.merged(into: [runningExchangeOverlap], now: exchangeNow)) == nil)
let exchangeBackup = StudyLogBackup(exportedAt: exchangeNow, segments: mergedLaptop, settings: .standard)
let exchangeRestored = try exchangeDecoder.decode(StudyLogBackup.self, from: encoder.encode(exchangeBackup))
let restoredLaptop = try exchangeRestored.validatedSegments()
assert(restoredLaptop == mergedLaptop, "Backup must retain origin and replay protection")
let phoneWire = try exchangeDecoder.decode(StudyExchange.self, from: Data(contentsOf: fixtureRoot.appendingPathComponent("phone-wire.json")))
assert((try? phoneWire.merged(into: [], now: exchangeNow)) == nil, "Phone cannot import its own direction")
print("PASS: Windows/iPhone wire fixtures, additive merge, replay, stale/changed refusal, overlap and provenance recovery")
