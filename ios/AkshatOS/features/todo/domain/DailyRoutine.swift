import Foundation

enum RoutinePeriod: String, Codable, CaseIterable, Identifiable, Hashable {
    case morning, day, evening
    var id: String { rawValue }
    var title: String { switch self { case .morning: "Morning"; case .day: "Day"; case .evening: "Evening" } }
    var symbol: String { switch self { case .morning: "sunrise"; case .day: "sun.max"; case .evening: "moon" } }
}
enum RoutineStatus: String, Codable { case pending, done, skipped }

struct RoutineItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var period: RoutinePeriod = .morning
    /// Local clock minutes, a target label only; never an alarm or inferred completion.
    var targetMinute: Int?
    var weekdays: [Int] = Array(1...7)
    var paused = false
}
struct RoutineCheck: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String
    var period: RoutinePeriod
    var targetMinute: Int?
    var status: RoutineStatus = .pending
    var recordedAt: Date?
}
struct RoutineDay: Codable, Equatable, Identifiable {
    var day: String
    var zone: String
    var checks: [RoutineCheck]
    var id: String { day }
    var done: Int { checks.filter { $0.status == .done }.count }
    var skipped: Int { checks.filter { $0.status == .skipped }.count }
}
struct DailyRoutine: Codable, Equatable {
    var items: [RoutineItem] = []
    var days: [RoutineDay] = []

    func validated() throws -> Self {
        let clock = ActivityDayClock()
        guard items.count <= 100, days.count <= 36_600,
              Set(items.map(\.id)).count == items.count,
              Set(days.map(\.day)).count == days.count,
              items.allSatisfy({ validTitle($0.title) && validMinute($0.targetMinute)
                  && !$0.weekdays.isEmpty && Set($0.weekdays).count == $0.weekdays.count
                  && $0.weekdays.allSatisfy { (1...7).contains($0) } }),
              days.allSatisfy({ day in
                  clock.date(day.day) != nil && TimeZone(identifier: day.zone) != nil
                  && day.checks.count <= 200 && Set(day.checks.map(\.id)).count == day.checks.count
                  && day.checks.allSatisfy { validTitle($0.title) && validMinute($0.targetMinute)
                      && ($0.status == .pending ? $0.recordedAt == nil : $0.recordedAt != nil) }
              }) else { throw PersonalDataError.invalid("The routine contains invalid items or daily records.") }
        return self
    }
    private func validTitle(_ title: String) -> Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 250
    }
    private func validMinute(_ minute: Int?) -> Bool { minute.map { (0..<1440).contains($0) } ?? true }

    /// Only today's snapshot is reconciled. Finished/skipped rows and all closed days are retained.
    /// Missing unopened days stay unrecorded rather than becoming invented failures.
    mutating func prepare(at date: Date, clock: ActivityDayClock) {
        guard !items.isEmpty || !days.isEmpty else { return }
        let key = clock.key(date)
        guard let dayDate = clock.date(key) else { return }
        let weekday = clock.calendar.component(.weekday, from: dayDate)
        let scheduled = items.filter { !$0.paused && $0.weekdays.contains(weekday) }
        let index: Int
        if let found = days.firstIndex(where: { $0.day == key }) { index = found }
        else {
            days.append(RoutineDay(day: key, zone: clock.calendar.timeZone.identifier, checks: []))
            index = days.count - 1
        }
        let previous = days[index].checks
        var checks = scheduled.map { item -> RoutineCheck in
            if let saved = previous.first(where: { $0.id == item.id && $0.status != .pending }) { return saved }
            return RoutineCheck(id: item.id, title: item.title, period: item.period, targetMinute: item.targetMinute)
        }
        checks += previous.filter { saved in saved.status != .pending && !checks.contains { $0.id == saved.id } }
        days[index].checks = checks
    }
    mutating func record(_ id: UUID, status: RoutineStatus, day: String, at date: Date, clock: ActivityDayClock) throws {
        guard day == clock.key(date) else { throw PersonalDataError.invalid("The routine day changed. Reopen today's checklist and try again.") }
        prepare(at: date, clock: clock)
        guard let d = days.firstIndex(where: { $0.day == day }),
              let c = days[d].checks.firstIndex(where: { $0.id == id }) else {
            throw PersonalDataError.invalid("That routine item is no longer scheduled today.")
        }
        // Replays do not move the recorded timestamp.
        guard days[d].checks[c].status != status else { return }
        days[d].checks[c].status = status
        days[d].checks[c].recordedAt = status == .pending ? nil : date
    }
}
