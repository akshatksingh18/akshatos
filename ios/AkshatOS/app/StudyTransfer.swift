import Foundation
import CryptoKit

/// A complete snapshot of finished blocks. Consumers replace all pieces of each segment together;
/// an absent id in this explicit full snapshot is a deletion, never an extra study session.
struct StudyTransfer: Codable {
    struct Segment: Codable {
        struct Piece: Codable { var id: String; var studyDate: String; var start: Date; var end: Date; var seconds: Double; var minutes: Int }
        var id: UUID
        var revision: String
        var start: Date
        var end: Date
        var type: String
        var topic: String?
        var note: String?
        var timeZone: String
        var pieces: [Piece]
    }
    var format = "akshatos-study-sessions"
    var version = 2
    var sourceID: String
    var exportedAt: Date
    var revision: Int
    var fullSnapshot = true
    var excludedRunningIDs: [UUID]
    var segments: [Segment]
}

extension AppServices {
    func studyExport() throws -> Data {
        guard studyLog.storageAvailable else { throw PersonalDataError.invalid("Study data is unavailable. Nothing was exported.") }
        let defaults = UserDefaults.standard
        let source = defaults.string(forKey: "study.transfer-source") ?? UUID().uuidString
        let revision = defaults.integer(forKey: "study.transfer-revision") + 1
        let segments = try studyLog.log.segments.compactMap { segment -> StudyTransfer.Segment? in
            guard let end = segment.end else { return nil }
            let pieces = studyLog.clock.pieces(of: segment, now: end)
            // Round once per original block, then distribute its whole minutes. Split days must
            // never gain minutes through independent rounding.
            var remaining = Int(segment.duration(now: end) / 60)
            let transferred = pieces.enumerated().map { index, piece in
                let minutes = index == pieces.count - 1 ? remaining : min(remaining, Int(piece.duration / 60))
                remaining -= minutes
                return StudyTransfer.Segment.Piece(id: piece.id, studyDate: piece.day, start: piece.start,
                    end: piece.end, seconds: piece.duration, minutes: minutes)
            }
            let digest = SHA256.hash(data: try LocalDataCoding.encode(segment)).map { String(format: "%02x", $0) }.joined()
            let topic = (segment.topic ?? "").lowercased()
            let type = topic.contains("sql") ? "SQL" : topic.contains("dsa") ? "DSA lesson/Mixed practice"
                : topic.contains("project") || topic.contains("main") || topic.contains("ml") ? "main/project" : "other"
            return StudyTransfer.Segment(id: segment.id, revision: digest, start: segment.start, end: end,
                type: type, topic: segment.topic, note: segment.note, timeZone: segment.timeZoneID ?? studyLog.clock.calendar.timeZone.identifier, pieces: transferred)
        }
        let data = try LocalDataCoding.encode(StudyTransfer(sourceID: source, exportedAt: Date(), revision: revision,
            excludedRunningIDs: studyLog.log.segments.filter(\.isRunning).map(\.id), segments: segments))
        defaults.set(source, forKey: "study.transfer-source"); defaults.set(revision, forKey: "study.transfer-revision")
        return data
    }
}
