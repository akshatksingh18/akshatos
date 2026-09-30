import Foundation

/// The weekly tape sites, measured in inches. Raw values are stored and exported, so never rename
/// them. The set covers where fat loss shows (waist, lower belly, hips, thigh), where muscle gain
/// shows (chest, shoulders, upper arm), and the neck the body-fat estimate needs.
enum BodySite: String, CaseIterable, Codable, Identifiable {
    case waistNavel, lowerBelly, hips, neck, chest, shoulders, upperArmRight, thighRight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waistNavel: return "Waist (navel)"
        case .lowerBelly: return "Lower belly"
        case .hips: return "Hips"
        case .neck: return "Neck"
        case .chest: return "Chest"
        case .shoulders: return "Shoulders"
        case .upperArmRight: return "Upper arm (right)"
        case .thighRight: return "Thigh (right)"
        }
    }

    /// Where the tape goes. Consistency matters more than the exact spot, so the app shows this
    /// every time.
    var guidance: String {
        switch self {
        case .waistNavel: return "Level around the belly button, relaxed, after a normal breath out."
        case .lowerBelly: return "Level about 2 in below the belly button, relaxed."
        case .hips: return "Around the widest part of the glutes, feet together."
        case .neck: return "Just below the Adam's apple, sloping slightly down at the front."
        case .chest: return "Around the nipple line, arms down, after a normal breath out."
        case .shoulders: return "Around the widest part of the shoulders, arms relaxed at your sides."
        case .upperArmRight: return "Right arm flexed, around the peak of the biceps."
        case .thighRight: return "Right thigh, standing, around the widest part below the glutes."
        }
    }

    /// Column name in the CSV export.
    var csvColumn: String {
        switch self {
        case .waistNavel: return "waist_navel_in"
        case .lowerBelly: return "lower_belly_in"
        case .hips: return "hips_in"
        case .neck: return "neck_in"
        case .chest: return "chest_in"
        case .shoulders: return "shoulders_in"
        case .upperArmRight: return "upper_arm_right_in"
        case .thighRight: return "thigh_right_in"
        }
    }
}

/// One morning weigh-in, in pounds. A day holds at most one; logging again replaces it.
struct BodyWeightEntry: Codable, Identifiable, Equatable {
    var id: UUID
    /// Local calendar day, `yyyy-MM-dd`.
    var day: String
    var pounds: Double
    var recordedAt: Date

    init(id: UUID = UUID(), day: String, pounds: Double, recordedAt: Date) {
        self.id = id
        self.day = day
        self.pounds = pounds
        self.recordedAt = recordedAt
    }
}

/// One tape session. Sites left blank are simply absent, so a partial week is still kept.
struct BodyMeasurement: Codable, Identifiable, Equatable {
    var id: UUID
    var day: String
    var recordedAt: Date
    /// Inches keyed by `BodySite.rawValue`. Unknown keys from a newer build are kept, not dropped.
    var inches: [String: Double]

    init(id: UUID = UUID(), day: String, recordedAt: Date, inches: [String: Double]) {
        self.id = id
        self.day = day
        self.recordedAt = recordedAt
        self.inches = inches
    }

    func value(_ site: BodySite) -> Double? { inches[site.rawValue] }
}

enum BodyPhotoPose: String, Codable, CaseIterable, Identifiable {
    case front, side
    var id: String { rawValue }
    var title: String { self == .front ? "Front" : "Side" }
}

/// A progress photo's record. The image itself is a file on the phone named after the id.
struct BodyPhoto: Codable, Identifiable, Equatable {
    var id: UUID
    var day: String
    var pose: BodyPhotoPose
    var recordedAt: Date

    init(id: UUID = UUID(), day: String, pose: BodyPhotoPose, recordedAt: Date) {
        self.id = id
        self.day = day
        self.pose = pose
        self.recordedAt = recordedAt
    }

    var fileName: String { "\(id.uuidString).jpg" }
}

/// Everything the module stores, newest first in each list.
struct BodyLogSnapshot: Equatable {
    var weights: [BodyWeightEntry] = []
    var measurements: [BodyMeasurement] = []
    var photos: [BodyPhoto] = []
}

/// One weekly block of weigh-ins. Blocks start on the measurement weekday.
struct BodyWeek: Equatable, Identifiable {
    let start: String
    let average: Double
    let count: Int
    var id: String { start }
}

enum BodyLogError: LocalizedError, Equatable {
    case invalidWeight
    case invalidMeasurement(String)
    case emptyMeasurement
    case invalidDay
    case invalidBackup(String)
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidWeight:
            return "Enter a weight between \(Int(BodyLog.weightRange.lowerBound)) and \(Int(BodyLog.weightRange.upperBound)) lb."
        case .invalidMeasurement(let site):
            return "\(site) must be between \(Int(BodyLog.inchRange.lowerBound)) and \(Int(BodyLog.inchRange.upperBound)) in."
        case .emptyMeasurement: return "Enter at least one measurement."
        case .invalidDay: return "That entry has an invalid date."
        case .invalidBackup(let reason): return "That backup is invalid: \(reason)."
        case .unsupportedVersion: return "That backup was made by a newer version of AkshatOS."
        }
    }
}

enum BodyLog {
    static let weightRange = 50.0...700.0
    static let inchRange = 5.0...80.0
    /// Progress photos are due once the latest is this many days old, matching a two-week rhythm.
    static let photoIntervalDays = 14

    // MARK: - Days

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(fromDay day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, day.count == 10,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              dayKey(date, calendar: calendar) == day else { return nil }
        return date
    }

    static func adding(days: Int, to day: String, calendar: Calendar) -> String? {
        guard let date = date(fromDay: day, calendar: calendar),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return nil }
        return dayKey(moved, calendar: calendar)
    }

    /// The first day of the weekly block holding `day`. `weekday` is Calendar's 1 (Sunday) … 7
    /// (Saturday).
    static func weekStart(for day: String, weekday: Int, calendar: Calendar) -> String? {
        guard let date = date(fromDay: day, calendar: calendar) else { return nil }
        let back = (calendar.component(.weekday, from: date) - weekday + 7) % 7
        return adding(days: -back, to: day, calendar: calendar)
    }

    // MARK: - Validation

    static func validatedWeight(_ pounds: Double) throws -> Double {
        guard pounds.isFinite, weightRange.contains(pounds) else { throw BodyLogError.invalidWeight }
        return (pounds * 10).rounded() / 10
    }

    /// Checks every entered site and rounds to a hundredth of an inch.
    static func validatedInches(_ values: [BodySite: Double]) throws -> [String: Double] {
        guard !values.isEmpty else { throw BodyLogError.emptyMeasurement }
        var checked: [String: Double] = [:]
        for (site, value) in values {
            guard value.isFinite, inchRange.contains(value) else {
                throw BodyLogError.invalidMeasurement(site.title)
            }
            checked[site.rawValue] = (value * 100).rounded() / 100
        }
        return checked
    }

    // MARK: - Weight trends

    /// Mean of the weigh-ins in the seven days ending on `day`, inclusive.
    static func rollingAverage(_ weights: [BodyWeightEntry], endingOn day: String,
                               calendar: Calendar) -> Double? {
        guard let first = adding(days: -6, to: day, calendar: calendar) else { return nil }
        let window = weights.filter { $0.day >= first && $0.day <= day }
        guard !window.isEmpty else { return nil }
        return window.reduce(0) { $0 + $1.pounds } / Double(window.count)
    }

    /// Weekly averages, newest block first.
    static func weeklyAverages(_ weights: [BodyWeightEntry], weekday: Int,
                               calendar: Calendar) -> [BodyWeek] {
        let groups = Dictionary(grouping: weights) {
            weekStart(for: $0.day, weekday: weekday, calendar: calendar) ?? $0.day
        }
        return groups.map { start, values in
            BodyWeek(start: start, average: values.reduce(0) { $0 + $1.pounds } / Double(values.count),
                     count: values.count)
        }
        .sorted { $0.start > $1.start }
    }

    // MARK: - Measurements

    /// How much a site changed since the most recent earlier session that measured it.
    static func change(for site: BodySite, in measurement: BodyMeasurement,
                       history: [BodyMeasurement]) -> Double? {
        guard let current = measurement.value(site) else { return nil }
        let earlier = history
            .filter { $0.id != measurement.id && $0.day < measurement.day && $0.value(site) != nil }
            .max { $0.day < $1.day }
        return earlier?.value(site).map { current - $0 }
    }

    /// US Navy circumference estimate, male formula, all in inches. An estimate, not a measurement:
    /// nil whenever the inputs cannot produce a meaningful number.
    static func navyBodyFat(waist: Double, neck: Double, height: Double) -> Double? {
        guard waist > neck, neck > 0, height > 0 else { return nil }
        let value = 86.010 * log10(waist - neck) - 70.041 * log10(height) + 36.76
        return value.isFinite && value > 0 && value < 75 ? value : nil
    }

    static func waistToHeight(waist: Double, height: Double) -> Double? {
        guard waist > 0, height > 0 else { return nil }
        return waist / height
    }

    // MARK: - Photos

    static func photosDue(_ photos: [BodyPhoto], today: String, calendar: Calendar) -> Bool {
        guard let latest = photos.map(\.day).max() else { return true }
        guard let dueDay = adding(days: photoIntervalDays, to: latest, calendar: calendar) else { return true }
        return today >= dueDay
    }

    // MARK: - Export

    /// One row per day that has a weigh-in or a measurement, oldest first, in the same inches and
    /// pounds the app shows. Blank cells mean not measured that day.
    static func csv(_ snapshot: BodyLogSnapshot) -> String {
        let header = (["date", "weight_lb"] + BodySite.allCases.map(\.csvColumn)).joined(separator: ",")
        let weights = Dictionary(snapshot.weights.map { ($0.day, $0.pounds) }, uniquingKeysWith: { a, _ in a })
        let measured = Dictionary(grouping: snapshot.measurements, by: \.day)
        let days = Set(weights.keys).union(measured.keys).sorted()
        let rows = days.map { day -> String in
            let latest = measured[day]?.max { $0.recordedAt < $1.recordedAt }
            let cells = [day, weights[day].map(number) ?? ""]
                + BodySite.allCases.map { site in latest?.value(site).map(number) ?? "" }
            return cells.joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    static func number(_ value: Double) -> String {
        var text = String(format: "%.2f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }
}

/// The restorable backup: every record, plus the photo files beside it when exported as a folder.
struct BodyLogBackup: Codable, Equatable {
    static let currentVersion = 1
    static let manifestName = "body-log.json"
    static let photosFolder = "photos"

    var version: Int
    var exportedAt: Date
    var weights: [BodyWeightEntry]
    var measurements: [BodyMeasurement]
    var photos: [BodyPhoto]
    /// Settings the estimates depend on. Optional, so backups made before they were carried still
    /// read; a backup without them leaves the phone's settings as they are.
    var heightInches: Double?
    var measurementWeekday: Int?

    init(exportedAt: Date, snapshot: BodyLogSnapshot,
         heightInches: Double? = nil, measurementWeekday: Int? = nil) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        weights = snapshot.weights
        measurements = snapshot.measurements
        photos = snapshot.photos
        self.heightInches = heightInches
        self.measurementWeekday = measurementWeekday
    }

    var snapshot: BodyLogSnapshot {
        BodyLogSnapshot(weights: weights, measurements: measurements, photos: photos)
    }

    /// Checks the whole backup before anything is replaced.
    func validated(calendar: Calendar) throws -> BodyLogBackup {
        guard version >= 1 else { throw BodyLogError.invalidBackup("unknown version") }
        guard version <= Self.currentVersion else { throw BodyLogError.unsupportedVersion }
        let ids = weights.map(\.id) + measurements.map(\.id) + photos.map(\.id)
        guard Set(ids).count == ids.count else { throw BodyLogError.invalidBackup("duplicate records") }
        guard Set(weights.map(\.day)).count == weights.count else {
            throw BodyLogError.invalidBackup("two weights on one day")
        }
        if let heightInches, !(36...96).contains(heightInches) {
            throw BodyLogError.invalidBackup("height out of range")
        }
        if let measurementWeekday, !(1...7).contains(measurementWeekday) {
            throw BodyLogError.invalidBackup("measurement day out of range")
        }
        let days = weights.map(\.day) + measurements.map(\.day) + photos.map(\.day)
        guard days.allSatisfy({ BodyLog.date(fromDay: $0, calendar: calendar) != nil }) else {
            throw BodyLogError.invalidDay
        }
        for weight in weights { _ = try BodyLog.validatedWeight(weight.pounds) }
        for measurement in measurements {
            let known = Dictionary(uniqueKeysWithValues: BodySite.allCases.compactMap { site in
                measurement.value(site).map { (site, $0) }
            })
            guard !measurement.inches.isEmpty else { throw BodyLogError.emptyMeasurement }
            if !known.isEmpty { _ = try BodyLog.validatedInches(known) }
        }
        return self
    }
}
