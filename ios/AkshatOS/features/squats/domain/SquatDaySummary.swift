import Foundation

struct SquatPauseSegment: Identifiable, Equatable {
    let id: String
    let started: Date
    let ended: Date

    var duration: TimeInterval { max(0, ended.timeIntervalSince(started)) }
}

struct SquatDaySummary: Identifiable, Equatable {
    enum GoalStatus: Equatable { case notSet, reached, atRisk, missed }

    let day: String
    let sessions: [SquatSession]
    let started: Date
    let ended: Date?
    let completedSets: Int
    let goal: Int?
    let goalStatus: GoalStatus
    let activeDuration: TimeInterval
    let pausedDuration: TimeInterval
    let pauseSegments: [SquatPauseSegment]
    let completionTimes: [Date]
    let snoozeTimes: [Date]
    let intervals: [Int]

    var id: String { day }
    var events: [SquatEvent] { sessions.flatMap(\.events).sorted { $0.date < $1.date } }

    static func make(day: String, sessions: [SquatSession], now: Date = Date(),
                     calendar: Calendar = .current) -> SquatDaySummary? {
        let values = sessions.filter { $0.day == day }.sorted { $0.started < $1.started }
        guard let first = values.first else { return nil }
        let completed = values.reduce(0) { $0 + $1.count }
        let goal = first.goal
        let status: GoalStatus
        if let goal {
            if completed >= goal { status = .reached }
            else if day == SquatSession.dayKey(now, calendar: calendar) { status = .atRisk }
            else { status = .missed }
        } else { status = .notSet }

        var pauses: [SquatPauseSegment] = []
        var active: TimeInterval = 0
        for session in values {
            let effectiveEnd = max(session.started, session.ended ?? now)
            let firstPauseIndex = pauses.endIndex
            var pauseStart: Date?
            for event in session.events.sorted(by: { $0.date < $1.date }) {
                let eventDate = min(max(event.date, session.started), effectiveEnd)
                switch event.kind {
                case .pause where pauseStart == nil:
                    pauseStart = eventDate
                case .resume:
                    if let start = pauseStart {
                        pauses.append(SquatPauseSegment(
                            id: "\(session.id.uuidString)-\(start.timeIntervalSinceReferenceDate)",
                            started: start, ended: max(start, eventDate)))
                        pauseStart = nil
                    }
                default: break
                }
            }
            if let start = pauseStart {
                pauses.append(SquatPauseSegment(
                    id: "\(session.id.uuidString)-\(start.timeIntervalSinceReferenceDate)",
                    started: start, ended: effectiveEnd))
            }
            let elapsed = effectiveEnd.timeIntervalSince(session.started)
            let sessionPaused = pauses[firstPauseIndex...].reduce(0) { $0 + $1.duration }
            active += max(0, elapsed - sessionPaused)
        }
        let paused = pauses.reduce(0) { $0 + $1.duration }
        let events = values.flatMap(\.events)
        return SquatDaySummary(
            day: day,
            sessions: values,
            started: first.started,
            ended: values.allSatisfy({ $0.ended != nil }) ? values.compactMap(\.ended).max() : nil,
            completedSets: completed,
            goal: goal,
            goalStatus: status,
            activeDuration: active,
            pausedDuration: paused,
            pauseSegments: pauses.sorted { $0.started < $1.started },
            completionTimes: events.filter { $0.kind == .done }.map(\.date).sorted(),
            snoozeTimes: events.filter { $0.kind == .snooze }.map(\.date).sorted(),
            intervals: Array(Set(values.map(\.interval))).sorted())
    }
}
