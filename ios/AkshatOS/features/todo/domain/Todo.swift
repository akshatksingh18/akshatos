import Foundation

struct TodoItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var note = ""
    var area = "Personal"
    var due: Date?
    var hasTime = false
    var repeatRule = "none"
    var repeatDays = 1
    var weekdays: [Int] = []
    var repeatFromCompletion = false
    var createdAt = Date()
    var completedAt: Date?
    var archivedAt: Date?
}
struct ParkedThought: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var createdAt = Date()
    var day: String
    var zone: String
}
struct PriorityPlan: Codable, Identifiable, Equatable {
    var day: String
    var zone: String
    var selected: [UUID] = []
    var completed: Set<UUID> = []
    var id: String { day }
    var qualifies: Bool { !selected.isEmpty && Set(selected).isSubset(of: completed) }
}
struct TodoState: Codable, Equatable {
    var version = 1
    var tasks: [TodoItem] = []
    var thoughts: [ParkedThought] = []
    var plans: [PriorityPlan] = []
    var areas = ["Study", "Job", "Health", "Personal"]
    func validated() throws -> Self {
        guard version == 1, tasks.count <= 100_000, thoughts.count <= 100_000,
              Set(tasks.map(\.id)).count == tasks.count,
              Set(thoughts.map(\.id)).count == thoughts.count,
              Set(plans.map(\.day)).count == plans.count,
              tasks.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.title.count <= 1000 && $0.note.count <= 100_000
                  && ["none", "daily", "weekdays", "weekly", "interval"].contains($0.repeatRule)
                  && (1...3650).contains($0.repeatDays) && $0.weekdays.allSatisfy { (1...7).contains($0) } }),
              thoughts.allSatisfy({ !$0.text.isEmpty && $0.text.count <= 10_000
                  && ActivityDayClock().date($0.day) != nil && TimeZone(identifier: $0.zone) != nil }),
              plans.allSatisfy({ ActivityDayClock().date($0.day) != nil && $0.selected.count <= 3
                  && Set($0.selected).isSubset(of: Set(tasks.map(\.id)))
                  && Set($0.selected).count == $0.selected.count
                  && Set($0.selected).isSuperset(of: $0.completed)
                  && TimeZone(identifier: $0.zone) != nil }) else {
            throw PersonalDataError.invalid("The To-do file has an unsupported version or invalid records.")
        }
        return self
    }
    mutating func select(_ id: UUID, for day: String, clock: ActivityDayClock) throws {
        guard clock.date(day) != nil, let item = tasks.first(where: { $0.id == id }),
              item.completedAt == nil, item.archivedAt == nil else {
            throw PersonalDataError.invalid("Choose an unfinished task for this plan.")
        }
        if !plans.contains(where: { $0.day == day }) {
            plans.append(PriorityPlan(day: day, zone: clock.calendar.timeZone.identifier))
        }
        let index = plans.firstIndex { $0.day == day }!
        guard !plans[index].selected.contains(id) else { return }
        guard plans[index].selected.count < 3 else { throw PersonalDataError.invalid("Choose up to three priorities.") }
        plans[index].selected.append(id)
    }
    mutating func unselect(_ id: UUID, for day: String) {
        guard let index = plans.firstIndex(where: { $0.day == day }) else { return }
        plans[index].selected.removeAll { $0 == id }; plans[index].completed.remove(id)
    }
    /// Completion and creation of the next occurrence commit together as one snapshot.
    mutating func complete(_ id: UUID, at now: Date, clock: ActivityDayClock) throws -> UUID? {
        guard let index = tasks.firstIndex(where: { $0.id == id }), tasks[index].completedAt == nil,
              tasks[index].archivedAt == nil else { return nil }
        let original = tasks[index]
        tasks[index].completedAt = now
        if let plan = plans.firstIndex(where: { $0.day == clock.key(now) && $0.selected.contains(id) }) {
            plans[plan].completed.insert(id)
        }
        guard original.repeatRule != "none" else { return nil }
        var next = original; next.id = UUID(); next.createdAt = now; next.completedAt = nil
        next.due = try Self.nextDue(original, after: now, calendar: clock.calendar)
        tasks.append(next)
        return next.id
    }
    static func nextDue(_ item: TodoItem, after now: Date, calendar: Calendar) throws -> Date {
        let base = item.repeatFromCompletion ? now : (item.due ?? now)
        var cursor = base
        for _ in 0..<3700 {
            let step = item.repeatRule == "interval" ? item.repeatDays : 1
            guard let next = calendar.date(byAdding: .day, value: step, to: cursor) else { break }
            cursor = next
            let weekday = calendar.component(.weekday, from: cursor)
            let allowed = item.repeatRule == "weekdays" ? (2...6).contains(weekday)
                : item.repeatRule == "weekly" ? (item.weekdays.isEmpty
                    ? weekday == calendar.component(.weekday, from: base) : item.weekdays.contains(weekday)) : true
            if cursor > now && allowed { return cursor }
        }
        throw PersonalDataError.invalid("The next repeat date could not be calculated.")
    }
}

struct QuickTask {
    var title: String
    var due: Date?
    var hasTime: Bool
    /// Deliberately small, deterministic on-device grammar; unrecognised words remain in the title.
    static func parse(_ text: String, now: Date, calendar: Calendar) -> Self {
        var title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = title.lowercased()
        var date: Date?
        var match: String?
        if lower.contains("tomorrow") { date = calendar.date(byAdding: .day, value: 1, to: now); match = "tomorrow" }
        else if lower.contains("today") { date = now; match = "today" }
        else if let range = lower.range(of: #"\bin \d{1,3} days?\b"#, options: .regularExpression) {
            let phrase = String(lower[range]); let n = Int(phrase.filter(\.isNumber)) ?? 1
            date = calendar.date(byAdding: .day, value: n, to: now); match = phrase
        } else {
            let names = ["sun(?:day)?", "mon(?:day)?", "tue(?:sday)?", "wed(?:nesday)?", "thu(?:rsday)?", "fri(?:day)?", "sat(?:urday)?"]
            for (i, name) in names.enumerated() {
                if lower.range(of: "\\b" + name + "\\b", options: .regularExpression) != nil {
                    var distance = (i + 1 - calendar.component(.weekday, from: now) + 7) % 7
                    if distance == 0 { distance = 7 }
                    date = calendar.date(byAdding: .day, value: distance, to: now)
                    match = name; break
                }
            }
        }
        var timed = false
        if let expression = try? NSRegularExpression(pattern: #"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b"#, options: .caseInsensitive),
           let found = expression.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let hourRange = Range(found.range(at: 1), in: title),
           let meridianRange = Range(found.range(at: 3), in: title),
           let rawHour = Int(title[hourRange]), (1...12).contains(rawHour) {
            let minute = Range(found.range(at: 2), in: title).flatMap { Int(title[$0]) } ?? 0
            if (0...59).contains(minute) {
                let hour = rawHour % 12 + (title[meridianRange].lowercased() == "pm" ? 12 : 0)
                date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date ?? now)
                timed = date != nil
                if let range = Range(found.range, in: title) { title.removeSubrange(range) }
            }
        }
        if let match { title = title.replacingOccurrences(of: "\\b" + match + "\\b", with: "", options: [.regularExpression, .caseInsensitive]) }
        title = title.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
        return Self(title: title.isEmpty ? text : title, due: date, hasTime: timed)
    }
}
