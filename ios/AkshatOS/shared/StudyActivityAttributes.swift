import Foundation
import ActivityKit

/// Only a clock projection crosses into the extension: no topic, tasks, Journal or database access.
struct StudyActivityAttributes: ActivityAttributes {
    var sessionID: UUID
    var createdAt: Date

    struct ContentState: Codable, Hashable {
        var anchor: Date
        var studiedAtAnchor: TimeInterval
        var target: Int
        var validUntil: Date

        var elapsedOrigin: Date { anchor.addingTimeInterval(-max(0, studiedAtAnchor)) }
        var targetDate: Date { anchor.addingTimeInterval(max(0, Double(target) - studiedAtAnchor)) }
        var elapsedRange: ClosedRange<Date> { elapsedOrigin...max(elapsedOrigin, validUntil) }
        var remainingRange: ClosedRange<Date> { min(anchor, targetDate)...targetDate }

        func studied(at date: Date) -> TimeInterval {
            max(0, studiedAtAnchor + max(0, min(date, validUntil).timeIntervalSince(anchor)))
        }
    }
}
