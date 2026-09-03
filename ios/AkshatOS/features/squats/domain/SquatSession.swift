import Foundation

// Pure domain types: no UI, permissions, or notification side effects.
struct SquatEvent: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case done, pause, resume, snooze }
    var id = UUID()
    var date: Date
    var kind: Kind
}

struct SquatSession: Codable, Identifiable, Equatable {
    enum State: String, Codable { case running, paused, ended }
    var id = UUID()
    var day: String
    var started: Date
    var ended: Date?
    var interval: Int
    var goal: Int?
    var state: State = .paused
    var events: [SquatEvent] = []

    var count: Int { events.filter { $0.kind == .done }.count }
    var isActive: Bool { state != .ended }

    mutating func log(_ event: SquatEvent) {
        guard isActive, !events.contains(where: { $0.id == event.id }) else { return }
        events.append(event)
    }

    mutating func undo() {
        guard isActive, let index = events.lastIndex(where: { $0.kind == .done }) else { return }
        events.remove(at: index)
    }

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func streaks(_ sessions: [SquatSession], now: Date = Date(),
                        calendar: Calendar = .current) -> (current: Int, best: Int) {
        let groups = Dictionary(grouping: sessions, by: \.day)
        let qualified = Set(groups.compactMap { day, values -> String? in
            guard let goal = values.sorted(by: { $0.started < $1.started }).first?.goal,
                  values.reduce(0, { $0 + $1.count }) >= goal else { return nil }
            return day
        })
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        var best = 0
        var length = 0
        var previous: Date?
        for key in qualified.sorted() {
            guard let date = formatter.date(from: key) else { continue }
            let consecutive = previous.map {
                calendar.dateComponents([.day], from: $0, to: date).day == 1
            } ?? false
            length = consecutive ? length + 1 : 1
            best = max(best, length)
            previous = date
        }
        var cursor = calendar.startOfDay(for: now)
        if !qualified.contains(dayKey(cursor, calendar: calendar)) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var current = 0
        while qualified.contains(dayKey(cursor, calendar: calendar)) {
            current += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return (current, best)
    }
}
