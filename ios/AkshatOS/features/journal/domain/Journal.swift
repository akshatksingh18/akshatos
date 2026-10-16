import Foundation

struct JournalEntry: Codable, Identifiable, Equatable {
    var day: String
    var zone: String
    var text = ""
    var wentWell = ""
    var change = ""
    var learned = ""
    var mood: Int?
    var energy: Int?
    var photos: [String] = []
    var facts: JournalDayFacts?
    var updatedAt = Date()
    var completedAt: Date?
    var id: String { day }
    var hasWriting: Bool {
        [text, wentWell, change, learned].contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    var qualifies: Bool { hasWriting && completedAt != nil }
    var markdown: String {
        var lines = ["# " + day, text]
        for (title, body) in [("What went well", wentWell), ("What to change", change), ("One thing learned", learned)] where !body.isEmpty {
            lines += ["## " + title, body]
        }
        if let mood { lines.append("Mood: \(mood)/5") }
        if let energy { lines.append("Energy: \(energy)/5") }
        lines += photos.map { "![Photo](photos/\($0))" }
        return lines.joined(separator: "\n\n")
    }
}
struct JournalState: Codable, Equatable {
    var version = 1
    var entries: [JournalEntry] = []
    var weeklyNotes: [String: String] = [:]
    func validated() throws -> Self {
        guard version == 1, entries.count <= 50_000, Set(entries.map(\.day)).count == entries.count,
              entries.allSatisfy({ entry in
                  ActivityDayClock().date(entry.day) != nil && TimeZone(identifier: entry.zone) != nil
                  && entry.text.count <= 1_000_000 && entry.wentWell.count <= 100_000
                  && entry.change.count <= 100_000 && entry.learned.count <= 100_000
                  && (entry.mood == nil || (1...5).contains(entry.mood!))
                  && (entry.energy == nil || (1...5).contains(entry.energy!))
                  && entry.photos.count <= 20 && Set(entry.photos).count == entry.photos.count
                  && entry.photos.allSatisfy { LocalDataCoding.plainName($0) && $0.hasSuffix(".jpg") }
                  && (entry.completedAt == nil || entry.hasWriting)
              }), weeklyNotes.allSatisfy({ ActivityDayClock().date($0.key) != nil && $0.value.count <= 10_000 }) else {
            throw PersonalDataError.invalid("The Journal file contains invalid dates, entries or photo names.")
        }
        return self
    }
}
