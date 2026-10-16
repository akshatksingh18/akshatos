import Foundation

/// New records retain their activity-day key and originating zone; calendar deadlines are separate.
struct ActivityDayClock {
    var calendar: Calendar
    init(calendar: Calendar = .current) {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = calendar.timeZone
        self.calendar = value
    }
    func key(_ date: Date) -> String {
        var day = calendar.startOfDay(for: date)
        if calendar.component(.hour, from: date) < 3 {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return calendarKey(day)
    }
    func calendarKey(_ date: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }
    func date(_ key: String) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, key.count == 10, (1...12).contains(p[1]), (1...31).contains(p[2]),
              let result = calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2], hour: 12)),
              calendarKey(result) == key else { return nil }
        return result
    }
    func shifted(_ key: String, by days: Int) -> String? {
        date(key).flatMap { calendar.date(byAdding: .day, value: days, to: $0) }.map(calendarKey)
    }
    func start(_ key: String) -> Date? {
        date(key).flatMap { calendar.date(bySettingHour: 3, minute: 0, second: 0, of: $0) }
    }
    func week(_ key: String) -> [String] {
        guard let day = date(key) else { return [] }
        let distance = (calendar.component(.weekday, from: day) + 5) % 7
        return (0..<7).compactMap { shifted(key, by: $0 - distance) }
    }
}

enum PersonalDataError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case let .invalid(message) = self { return message }; return nil }
}

enum LocalDataCoding {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        guard data.count <= 25_000_000 else { throw PersonalDataError.invalid("The saved document exceeds the 25 MB recovery limit. Shorten the content or keep a separate export.") }
        return data
    }
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        guard data.count <= 25_000_000 else { throw PersonalDataError.invalid("That file is too large.") }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    static func csv(_ value: String) -> String {
        let first = value.trimmingCharacters(in: .whitespacesAndNewlines).first
        let safe = first.map { "=+-@".contains($0) } == true ? "'" + value : value
        return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    static func plainName(_ value: String) -> Bool {
        !value.isEmpty && value != "." && value != ".." && !value.contains("/") && !value.contains("\\")
            && !value.contains(":") && !value.contains("\0")
    }
}

/// App-owned composition consumes immutable, privacy-safe facts, never another feature's store.
struct HubDaySummary: Equatable {
    enum Availability: String { case available, noData, unavailable }
    var source: String
    var day: String
    var asOf: Date
    var availability: Availability
    var completed: Int = 0
    var selected: Int = 0
    var qualifies: Bool? = nil
}
@MainActor protocol HubDayPart: AnyObject {
    func daySummary(_ day: String, at date: Date) -> HubDaySummary
}

struct JournalDayFacts: Codable, Equatable {
    var activityDay: String
    var capturedAt: Date
    var studySeconds: Double?
    var studyBlocks: Int?
    var completedTasks: Int?
    var selectedPriorities: Int?
    var completedPriorities: Int?
    var readingTitle: String?
    var readingPage: Int?
}
