import Foundation

enum ActivityProgress {
    static func streak(_ qualified: Set<String>, today: String, clock: ActivityDayClock) -> (current: Int, best: Int) {
        var cursor = qualified.contains(today) ? today : (clock.shifted(today, by: -1) ?? today)
        var current = 0
        while qualified.contains(cursor), current <= qualified.count {
            current += 1
            guard let previous = clock.shifted(cursor, by: -1) else { break }; cursor = previous
        }
        var best = 0, length = 0, previous: String?
        for day in qualified.filter({ $0 <= today }).sorted() {
            length = previous.flatMap { clock.shifted($0, by: 1) } == day ? length + 1 : 1
            best = max(best, length); previous = day
        }
        return (current, best)
    }
    static let milestones = [10, 30, 100, 365]
}
