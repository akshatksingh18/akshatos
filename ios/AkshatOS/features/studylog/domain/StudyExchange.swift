import Foundation

/// Additive, immutable finished-session exchange. This is intentionally not backup replacement.
struct StudyExchange: Codable {
    struct Session: Codable {
        var id: UUID
        var start: Date
        var end: Date
        var timeZone: String
        var targetSeconds: Int
        var topic: String
    }
    var format = "akshatos-study-exchange"
    var version = 1
    var sourceID: UUID
    var device: String
    var revision: Int
    var exportedAt: Date
    var sessions: [Session]

    func merged(into existing: [StudySegment], now: Date) throws -> [StudySegment] {
        guard format == "akshatos-study-exchange", version == 1, device == "laptop", revision >= 0,
              sourceID.uuidString != "00000000-0000-0000-0000-000000000000",
              exportedAt <= now.addingTimeInterval(120), sessions.count <= 10_000,
              Set(sessions.map(\.id)).count == sessions.count else { throw StudyExchangeError.invalid }
        let previous = existing.filter { $0.exchangeOriginID == sourceID }
        guard revision >= (previous.compactMap(\.exchangeOriginRevision).max() ?? 0) else { throw StudyExchangeError.stale }
        var result = existing
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        for item in sessions {
            guard item.start >= Date(timeIntervalSince1970: 0), item.end > item.start, item.end <= now,
                  item.id.uuidString != "00000000-0000-0000-0000-000000000000",
                  (1...86400).contains(item.targetSeconds), item.topic.count <= 200,
                  TimeZone(identifier: item.timeZone) != nil else { throw StudyExchangeError.invalid }
            if let saved = byID[item.id] {
                guard saved.exchangeOriginID == sourceID, saved.start == item.start, saved.end == item.end,
                      saved.dayTarget == item.targetSeconds, (saved.topic ?? "") == item.topic,
                      saved.timeZoneID == item.timeZone else { throw StudyExchangeError.changed }
            } else {
                var segment = StudySegment(id: item.id, start: item.start, end: item.end, source: .manual,
                    dayTarget: item.targetSeconds, topic: item.topic.isEmpty ? nil : item.topic, timeZoneID: item.timeZone)
                segment.exchangeOriginID = sourceID; segment.exchangeOriginRevision = revision
                result.append(segment)
            }
        }
        for index in result.indices where result[index].exchangeOriginID == sourceID {
            result[index].exchangeOriginRevision = revision
        }
        // This includes the phone's current running block; overlap never becomes extra daily time.
        return try StudyLog.validated(result)
    }
}

enum StudyExchangeError: LocalizedError {
    case invalid, stale, changed
    var errorDescription: String? {
        switch self {
        case .invalid: return "Choose a valid finished-session file exported by Study Desk."
        case .stale: return "This laptop file is older than an import already saved."
        case .changed: return "An existing session differs. Resolve the correction before importing. No records were replaced."
        }
    }
}
