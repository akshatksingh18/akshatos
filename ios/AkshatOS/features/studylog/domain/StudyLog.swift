import Foundation

// Pure domain types for Study Log: no SwiftData, SwiftUI or file-system side effects.
// Time is stored as start and end timestamps, never as a ticking counter, so suspension, relaunch
// or a killed app can neither lose nor inflate study time.

/// One stretch of real study: from Start to Pause. `end` is nil while it is running.
struct StudySegment: Codable, Identifiable, Equatable {
    enum Source: String, Codable { case timer, manual }

    var id: UUID
    var start: Date
    var end: Date?
    var source: Source
    var note: String?
    /// The day's target in force when this block began, in seconds. The first block of a day sets
    /// that day's target, so changing the target later never rewrites an earlier day.
    var dayTarget: Int
    var dayFloor: Int?
    var dayGoal: Int?
    var topic: String?
    var timeZoneID: String?

    init(id: UUID = UUID(), start: Date, end: Date? = nil, source: Source = .timer,
         note: String? = nil, dayTarget: Int, topic: String? = nil, timeZoneID: String? = nil, dayFloor: Int? = nil, dayGoal: Int? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.source = source
        self.note = note
        self.dayTarget = dayTarget
        self.dayFloor = dayFloor
        self.dayGoal = dayGoal
        self.topic = topic
        self.timeZoneID = timeZoneID
    }

    var isRunning: Bool { end == nil }

    /// How long this block has run, up to `now` while it is still running.
    func duration(now: Date) -> TimeInterval {
        max(0, (end ?? max(now, start)).timeIntervalSince(start))
    }
}

enum StudyLogError: LocalizedError, Equatable {
    case invalidSegment
    case overlappingSegments
    case moreThanOneRunning
    case duplicateIdentifier
    case unsupportedVersion

    var errorDescription: String? {
        switch self {
        case .invalidSegment: return "A study block ends before it starts."
        case .overlappingSegments: return "Two study blocks overlap."
        case .moreThanOneRunning: return "More than one study block is running."
        case .duplicateIdentifier: return "Two study blocks share an identifier."
        case .unsupportedVersion: return "This Study Log backup is from a newer or unknown version."
        }
    }
}

/// The study day. It starts at 3:00 AM local time, so a late session stays with the day it began.
/// Days are keyed `yyyy-MM-dd` by the calendar date the study day starts on.
struct StudyDayClock {
    static let rolloverHour = 3
    var calendar: Calendar

    init(calendar: Calendar = .current) { self.calendar = calendar }

    /// The study day `date` falls in: before 3:00 AM it still belongs to the previous date.
    func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        var day = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day))!
        if (parts.hour ?? 0) < Self.rolloverHour {
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return Self.format(calendar.dateComponents([.year, .month, .day], from: day))
    }

    /// When the study day `key` begins: 3:00 AM local on that date.
    func start(of key: String) -> Date? {
        guard let parts = Self.parse(key) else { return nil }
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day,
                                                  hour: Self.rolloverHour))
    }

    /// The study day after `key`.
    func next(_ key: String) -> String? {
        guard let parts = Self.parse(key),
              let date = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day,
                                                            hour: 12)),
              let following = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
        return Self.format(calendar.dateComponents([.year, .month, .day], from: following))
    }

    func previous(_ key: String) -> String? {
        guard let parts = Self.parse(key),
              let date = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day,
                                                            hour: 12)),
              let before = calendar.date(byAdding: .day, value: -1, to: date) else { return nil }
        return Self.format(calendar.dateComponents([.year, .month, .day], from: before))
    }

    /// The parts of one block that fall in each study day: a block running past 3:00 AM counts
    /// up to 3:00 AM for its first day and the rest for the next.
    func pieces(of segment: StudySegment, now: Date) -> [StudyBlock] {
        var attributed = self
        if let name = segment.timeZoneID, let zone = TimeZone(identifier: name) { attributed.calendar.timeZone = zone }
        let end = segment.end ?? max(now, segment.start)
        var result: [StudyBlock] = []
        var cursor = segment.start
        while cursor < end {
            let day = attributed.key(for: cursor)
            guard let following = attributed.next(day), let boundary = attributed.start(of: following), boundary > cursor else { break }
            let pieceEnd = min(end, boundary)
            result.append(StudyBlock(segmentID: segment.id, day: day, start: cursor, end: pieceEnd,
                                     isRunning: segment.isRunning && pieceEnd == end, note: segment.note))
            cursor = pieceEnd
        }
        return result
    }

    /// The seven study days of the week containing `key`, starting on Monday.
    func week(containing key: String) -> [String] {
        guard let parts = Self.parse(key),
              let noon = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day,
                                                            hour: 12)) else { return [] }
        // Gregorian weekday: 1 is Sunday, 2 Monday … 7 Saturday.
        let weekday = calendar.component(.weekday, from: noon)
        let sinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: noon) else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
                .map { Self.format(calendar.dateComponents([.year, .month, .day], from: $0)) }
        }
    }

    /// The calendar date a study day is named after, at noon, for formatting.
    func date(of key: String) -> Date? {
        guard let parts = Self.parse(key) else { return nil }
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12))
    }

    private static func format(_ parts: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func parse(_ key: String) -> (year: Int, month: Int, day: Int)? {
        let fields = key.split(separator: "-").compactMap { Int($0) }
        guard fields.count == 3 else { return nil }
        return (fields[0], fields[1], fields[2])
    }
}

/// The part of a block inside one study day, which is what totals and lists show.
struct StudyBlock: Identifiable, Equatable {
    var segmentID: UUID
    var day: String
    var start: Date
    var end: Date
    var isRunning: Bool
    var note: String?

    var id: String { "\(segmentID.uuidString)#\(day)" }
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// One study day's summary.
struct StudyDaySummary: Identifiable, Equatable {
    var day: String
    var studied: TimeInterval
    var target: Int
    var blocks: [StudyBlock]

    var id: String { day }
}

/// The daily target and the two quiet marks on the progress bar, in seconds.
struct StudySettings: Codable, Equatable {
    static let standard = StudySettings(target: 6 * 3600, floor: 2 * 3600, goal: 4 * 3600)

    var target: Int
    var floor: Int
    var goal: Int

    /// Settings from a backup or preferences, kept to sensible ranges: a target of 30 minutes to
    /// 16 hours, and marks inside it in order.
    func validated() -> StudySettings {
        let target = min(max(self.target, 1800), 16 * 3600)
        let goal = min(max(self.goal, 0), target)
        let floor = min(max(self.floor, 0), goal)
        return StudySettings(target: target, floor: floor, goal: goal)
    }
}

/// Every study block, with the rules for starting, pausing, totals and history.
struct StudyLog: Equatable {
    var segments: [StudySegment] = []

    var running: StudySegment? { segments.first(where: \.isRunning) }

    /// Starts a block at `date` unless one is already running. Returns the new block, or nil when
    /// nothing changed, so a double tap or a repeated callback starts only one.
    @discardableResult
    mutating func start(at date: Date, target: Int, id: UUID = UUID(), topic: String? = nil, timeZoneID: String? = nil, dayFloor: Int? = nil, dayGoal: Int? = nil) -> StudySegment? {
        guard running == nil else { return nil }
        // Never start inside an earlier block, even if the clock was set back.
        let latestEnd = segments.compactMap(\.end).max() ?? .distantPast
        let segment = StudySegment(id: id, start: max(date, latestEnd), dayTarget: target, topic: topic, timeZoneID: timeZoneID, dayFloor: dayFloor, dayGoal: dayGoal)
        segments.append(segment)
        return segment
    }

    /// Blocks shorter than this are an accidental tap and are dropped on Pause.
    static let shortestBlock: TimeInterval = 5

    /// Ends the running block at `date`. Returns the finished block, or nil when nothing was running
    /// or the block was too short to keep (then it is removed).
    @discardableResult
    mutating func pause(at date: Date) -> StudySegment? {
        guard let index = segments.firstIndex(where: \.isRunning) else { return nil }
        let end = max(date, segments[index].start)
        guard end.timeIntervalSince(segments[index].start) >= Self.shortestBlock else {
            segments.remove(at: index)
            return nil
        }
        segments[index].end = end
        return segments[index]
    }

    func blocks(now: Date, clock: StudyDayClock) -> [StudyBlock] {
        segments.sorted { $0.start < $1.start }.flatMap { clock.pieces(of: $0, now: now) }
    }

    func studied(on day: String, now: Date, clock: StudyDayClock) -> TimeInterval {
        blocks(now: now, clock: clock).filter { $0.day == day }.reduce(0) { $0 + $1.duration }
    }

    /// Every day with study, newest first.
    func days(now: Date, clock: StudyDayClock, fallbackTarget: Int) -> [StudyDaySummary] {
        let grouped = Dictionary(grouping: blocks(now: now, clock: clock), by: \.day)
        return grouped.keys.sorted(by: >).map { day in
            let blocks = grouped[day] ?? []
            return StudyDaySummary(day: day, studied: blocks.reduce(0) { $0 + $1.duration },
                                   target: target(for: day, clock: clock) ?? fallbackTarget, blocks: blocks)
        }
    }

    /// The target the day's first block recorded, or nil for a day without study.
    func target(for day: String, clock: StudyDayClock) -> Int? { settings(for: day, clock: clock)?.target }
    func settings(for day: String, clock: StudyDayClock) -> StudySettings? {
        let first = segments.sorted { $0.start < $1.start }.first { segment in
            var attributed = clock
            if let name = segment.timeZoneID, let zone = TimeZone(identifier: name) { attributed.calendar.timeZone = zone }
            guard let start = attributed.start(of: day), let next = attributed.next(day), let end = attributed.start(of: next) else { return false }
            return segment.start < end && (segment.end ?? .distantFuture) > start
        }
        return first.map { StudySettings(target: $0.dayTarget, floor: $0.dayFloor ?? StudySettings.standard.floor,
            goal: $0.dayGoal ?? StudySettings.standard.goal).validated() }
    }

    /// Checks a set of blocks as a whole before it is saved or restored: real durations, unique ids,
    /// no overlaps, and at most one running block, which must be the latest.
    static func validated(_ segments: [StudySegment]) throws -> [StudySegment] {
        guard Set(segments.map(\.id)).count == segments.count else { throw StudyLogError.duplicateIdentifier }
        let sorted = segments.sorted { $0.start < $1.start }
        for segment in sorted {
            if let end = segment.end, end < segment.start { throw StudyLogError.invalidSegment }
            guard segment.dayTarget > 0, segment.dayTarget <= 24 * 3600,
                  segment.dayFloor == nil || (0...segment.dayTarget).contains(segment.dayFloor!),
                  segment.dayGoal == nil || (0...segment.dayTarget).contains(segment.dayGoal!),
                  segment.dayFloor == nil || segment.dayGoal == nil || segment.dayFloor! <= segment.dayGoal!,
                  (segment.topic?.count ?? 0) <= 200, (segment.note?.count ?? 0) <= 100_000,
                  segment.timeZoneID == nil || TimeZone(identifier: segment.timeZoneID!) != nil else { throw StudyLogError.invalidSegment }
        }
        let runningCount = sorted.filter(\.isRunning).count
        guard runningCount <= 1 else { throw StudyLogError.moreThanOneRunning }
        if runningCount == 1, sorted.last?.isRunning != true { throw StudyLogError.overlappingSegments }
        for (earlier, later) in zip(sorted, sorted.dropFirst()) {
            guard let end = earlier.end, end <= later.start else { throw StudyLogError.overlappingSegments }
        }
        return sorted
    }
}

/// The versioned backup: every block plus the settings. Restoring replaces everything.
struct StudyLogBackup: Codable, Equatable {
    static let currentVersion = 1
    var version: Int
    var exportedAt: Date
    var segments: [StudySegment]
    var settings: StudySettings?

    init(exportedAt: Date, segments: [StudySegment], settings: StudySettings?) {
        version = Self.currentVersion
        self.exportedAt = exportedAt
        self.segments = segments
        self.settings = settings
    }

    func validatedSegments() throws -> [StudySegment] {
        guard version == Self.currentVersion else { throw StudyLogError.unsupportedVersion }
        return try StudyLog.validated(segments)
    }
}

enum StudyTime {
    /// "5:42:10", hours not padded, as the Windows Clock shows a countdown.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// "2 h 15 m", "45 m" or "0 m", for totals in lists.
    static func short(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        if minutes < 60 { return "\(minutes) m" }
        return minutes % 60 == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(minutes % 60) m"
    }

    /// Hours for a target or mark: "6 h", "4.5 h".
    static func hours(_ seconds: Int) -> String {
        seconds % 3600 == 0 ? "\(seconds / 3600) h" : String(format: "%.1f h", Double(seconds) / 3600)
    }
}
