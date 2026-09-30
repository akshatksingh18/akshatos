import Foundation

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "UTC")!
let noon = calendar.date(from: DateComponents(year: 2026, month: 9, day: 19, hour: 12))!

// Days are local calendar keys; malformed or impossible ones are refused.
assert(BodyLog.dayKey(noon, calendar: calendar) == "2026-09-19", "A date becomes a zero-padded day key")
assert(BodyLog.date(fromDay: "2026-09-19", calendar: calendar) != nil, "A real day parses")
assert(BodyLog.date(fromDay: "2026-02-30", calendar: calendar) == nil, "An impossible day is refused")
assert(BodyLog.date(fromDay: "2026-9-1", calendar: calendar) == nil, "An unpadded key is refused")
assert(BodyLog.adding(days: -6, to: "2026-09-01", calendar: calendar) == "2026-08-26",
       "Day arithmetic crosses month boundaries")

// Weekly blocks start on the measurement weekday (7 = Saturday; 2026-09-19 is a Saturday).
assert(BodyLog.weekStart(for: "2026-09-19", weekday: 7, calendar: calendar) == "2026-09-19",
       "The measurement day starts its own block")
assert(BodyLog.weekStart(for: "2026-09-25", weekday: 7, calendar: calendar) == "2026-09-19",
       "The Friday after belongs to the same block")
assert(BodyLog.weekStart(for: "2026-09-26", weekday: 7, calendar: calendar) == "2026-09-26",
       "The next Saturday starts a new block")
assert(BodyLog.weekStart(for: "2026-09-19", weekday: 2, calendar: calendar) == "2026-09-14",
       "A Monday measurement day moves the block start")

// Validation.
assert((try? BodyLog.validatedWeight(180.04)) == 180.0, "Weight is rounded to a tenth of a pound")
assert((try? BodyLog.validatedWeight(20)) == nil && (try? BodyLog.validatedWeight(.nan)) == nil,
       "Impossible weights are refused")
assert((try? BodyLog.validatedInches([.waistNavel: 34.126])) == ["waistNavel": 34.13],
       "Inches are rounded to a hundredth and keyed by the stored raw value")
assert((try? BodyLog.validatedInches([:])) == nil, "An empty session is refused")
assert((try? BodyLog.validatedInches([.neck: 1])) == nil, "A site outside the tape range is refused")
assert(BodySite.allCases.map(\.rawValue) == ["waistNavel", "lowerBelly", "hips", "neck", "chest",
                                             "shoulders", "upperArmRight", "thighRight"],
       "Site raw values are stored and exported and must not be renamed")
assert(BodySite.allCases.allSatisfy { !$0.guidance.isEmpty && !$0.title.isEmpty },
       "Every site says where the tape goes")
print("PASS: 16 day, week and validation assertions")

// Weight trends: the rolling seven days, and weekly block averages.
func weight(_ day: String, _ pounds: Double) -> BodyWeightEntry {
    BodyWeightEntry(day: day, pounds: pounds, recordedAt: noon)
}
let weights = [weight("2026-09-12", 190), weight("2026-09-19", 182), weight("2026-09-20", 181),
               weight("2026-09-25", 180), weight("2026-09-26", 178)]
assert(BodyLog.rollingAverage(weights, endingOn: "2026-09-25", calendar: calendar) == 181,
       "The rolling average covers the seven days ending that day, inclusive")
assert(BodyLog.rollingAverage(weights, endingOn: "2026-09-10", calendar: calendar) == nil,
       "No weigh-ins in the window means no average rather than zero")
let blocks = BodyLog.weeklyAverages(weights, weekday: 7, calendar: calendar)
assert(blocks.map(\.start) == ["2026-09-26", "2026-09-19", "2026-09-12"], "Blocks are newest first")
assert(blocks[1].average == 181 && blocks[1].count == 3, "A block averages its own weigh-ins")
print("PASS: 4 weight-trend assertions")

// Measurements: change since the previous session that measured the same site.
let first = BodyMeasurement(day: "2026-09-12", recordedAt: noon, inches: ["waistNavel": 35, "neck": 15.5])
let second = BodyMeasurement(day: "2026-09-19", recordedAt: noon, inches: ["waistNavel": 34.5])
let third = BodyMeasurement(day: "2026-09-26", recordedAt: noon, inches: ["waistNavel": 34.25, "neck": 15.25])
let sessions = [third, second, first]
assert(BodyLog.change(for: .waistNavel, in: third, history: sessions) == -0.25,
       "Change is against the most recent earlier session")
assert(BodyLog.change(for: .neck, in: third, history: sessions) == -0.25,
       "A site skipped last week compares with the session that has it")
assert(BodyLog.change(for: .waistNavel, in: first, history: sessions) == nil, "The first session has no change")
assert(BodyLog.change(for: .hips, in: third, history: sessions) == nil, "An unmeasured site has no change")

// Estimates. The Navy formula (male, inches) is checked against a hand computation.
let navy = BodyLog.navyBodyFat(waist: 36, neck: 16, height: 70)!
assert(abs(navy - 19.43) < 0.01, "Navy estimate matches 86.010·log10(w−n) − 70.041·log10(h) + 36.76")
assert(BodyLog.navyBodyFat(waist: 15, neck: 16, height: 70) == nil, "A waist under the neck has no estimate")
assert(BodyLog.navyBodyFat(waist: 36, neck: 16, height: 0) == nil, "No height, no estimate")
assert(BodyLog.waistToHeight(waist: 36, height: 72) == 0.5, "Waist-to-height is a plain ratio")

// Photos are due every two weeks.
func photo(_ day: String) -> BodyPhoto { BodyPhoto(day: day, pose: .front, recordedAt: noon) }
assert(BodyLog.photosDue([], today: "2026-09-19", calendar: calendar), "No photos means photos are due")
assert(!BodyLog.photosDue([photo("2026-09-06")], today: "2026-09-19", calendar: calendar),
       "Thirteen days after the last photo is not yet due")
assert(BodyLog.photosDue([photo("2026-09-05")], today: "2026-09-19", calendar: calendar),
       "Fourteen days after the last photo is due")
print("PASS: 11 measurement, estimate and photo assertions")

// CSV: one row per day, oldest first, blank where nothing was measured.
let csv = BodyLog.csv(BodyLogSnapshot(weights: [weight("2026-09-19", 182), weight("2026-09-20", 181.5)],
                                      measurements: [second], photos: []))
let lines = csv.split(separator: "\n").map(String.init)
assert(lines[0] == "date,weight_lb,waist_navel_in,lower_belly_in,hips_in,neck_in,chest_in,shoulders_in,upper_arm_right_in,thigh_right_in",
       "The header names every column with its unit")
assert(lines[1] == "2026-09-19,182,34.5,,,,,,,", "A day with both a weigh-in and a session fills both")
assert(lines[2] == "2026-09-20,181.5,,,,,,,,", "A weigh-in-only day leaves the sites blank")
assert(BodyLog.number(34.25) == "34.25" && BodyLog.number(34.5) == "34.5" && BodyLog.number(180) == "180",
       "Numbers drop trailing zeros")

// Backup: validated whole, round-trips exactly.
let snapshot = BodyLogSnapshot(weights: weights, measurements: sessions, photos: [photo("2026-09-19")])
let backup = BodyLogBackup(exportedAt: noon, snapshot: snapshot)
let decoded = try! JSONDecoder().decode(BodyLogBackup.self, from: try! JSONEncoder().encode(backup))
assert(decoded == backup && decoded.version == BodyLogBackup.currentVersion, "A backup round-trips exactly")
assert((try? backup.validated(calendar: calendar)) != nil, "A consistent backup validates")
var twoOnOneDay = backup
twoOnOneDay.weights.append(weight("2026-09-19", 183))
assert((try? twoOnOneDay.validated(calendar: calendar)) == nil, "Two weigh-ins on one day are refused")
var duplicated = backup
duplicated.measurements.append(duplicated.measurements[0])
assert((try? duplicated.validated(calendar: calendar)) == nil, "A duplicated record is refused")
var newer = backup
newer.version = BodyLogBackup.currentVersion + 1
assert((try? newer.validated(calendar: calendar)) == nil, "A backup from a newer version is refused")
var badDay = backup
badDay.photos[0].day = "2026-13-01"
assert((try? badDay.validated(calendar: calendar)) == nil, "An impossible date is refused")
print("PASS: 10 export and backup assertions")
