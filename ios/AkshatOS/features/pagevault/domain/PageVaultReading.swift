import Foundation

// Reading status, bookmarks, and the daily-goal streak engine. Pure Foundation logic so the whole
// habit model is testable without a document, a store, or a device.

enum PageVaultReadingStatus: String, Codable, CaseIterable {
    case wantToRead, reading, finished

    var label: String {
        switch self {
        case .wantToRead: return "Want to read"
        case .reading: return "Reading"
        case .finished: return "Finished"
        }
    }
}

/// One evaluated day for one book. Rows are written while a goal is active, so a day inside the
/// evaluated window with no row means the goal was live and nothing was read.
struct PageVaultReadingDay: Codable, Identifiable, Equatable {
    var day: String
    var bookID: UUID
    /// High-water page as of the moment this day began, so re-reading earlier pages cannot inflate it.
    var startPage: Int
    var highestPage: Int
    /// The goal in effect for this day, frozen so a later goal change cannot rewrite history.
    /// Zero marks a deliberately unevaluated day, such as finishing a book with no replacement.
    var goal: Int

    var id: String { "\(day)#\(bookID.uuidString)" }
    var pagesRead: Int { max(0, highestPage - startPage) }
    var isEvaluated: Bool { goal > 0 }
    var goalMet: Bool { isEvaluated && pagesRead >= goal }

    mutating func reach(page: Int) {
        highestPage = max(highestPage, page)
    }
}

struct PageVaultStreak: Equatable {
    var current = 0
    var best = 0
    var todayPagesRead = 0
    var todayGoal = 0
    var todayMet = false
    /// A live goal that today has not met yet. The streak is not broken until the day rolls over.
    var isAtRisk = false
}

extension PageVaultReadingDay {
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    static func startOfDay(_ day: String, calendar: Calendar = .current) -> Date? {
        let pieces = day.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3,
              let date = calendar.date(from: DateComponents(year: pieces[0], month: pieces[1],
                                                            day: pieces[2])),
              dayKey(date, calendar: calendar) == day else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// Walks real calendar days from the first recorded day through today. A missing day inside that
    /// window is a miss; an unevaluated day is skipped without breaking the run; today is at risk
    /// rather than missed until it rolls over.
    static func streak(_ days: [PageVaultReadingDay], now: Date = Date(),
                       calendar: Calendar = .current) -> PageVaultStreak {
        let today = dayKey(now, calendar: calendar)
        let relevant = days.filter { $0.day <= today }
        guard let first = relevant.map(\.day).min(),
              let start = startOfDay(first, calendar: calendar) else { return PageVaultStreak() }

        var byDay: [String: [PageVaultReadingDay]] = [:]
        for row in relevant { byDay[row.day, default: []].append(row) }

        var result = PageVaultStreak()
        var run = 0
        var cursor = start
        while true {
            let key = dayKey(cursor, calendar: calendar)
            let rows = byDay[key] ?? []
            let evaluated = rows.filter(\.isEvaluated)
            if !evaluated.isEmpty {
                if evaluated.contains(where: \.goalMet) {
                    run += 1
                    result.best = max(result.best, run)
                } else if key != today {
                    run = 0
                }
            } else if rows.isEmpty && key != today {
                // The goal was live and the day produced nothing.
                run = 0
            }
            if key == today {
                let met = evaluated.contains(where: \.goalMet)
                result.todayPagesRead = evaluated.map(\.pagesRead).max() ?? 0
                result.todayGoal = evaluated.map(\.goal).max() ?? 0
                result.todayMet = met
                result.isAtRisk = !evaluated.isEmpty && !met
                break
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        result.current = run
        result.best = max(result.best, run)
        return result
    }
}
