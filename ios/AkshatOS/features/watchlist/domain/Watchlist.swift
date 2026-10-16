import Foundation

struct WatchTitle: Codable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var kind = "Movie"
    var mood = "Any mood"
    var note = ""
    var pick = false
    var origin = "phone"
    var deleted = false
}
struct WatchedEvent: Codable, Equatable, Identifiable {
    var id = UUID()
    var titleID: UUID
    var watched: Bool
    var date: Date
    var revision: Int
}
struct WatchlistTransfer: Codable, Equatable {
    var format = "akshatos-watchlist"
    var version = 1
    var sourceID: UUID
    var revision: Int
    var titles: [WatchTitle]
    func validated() throws -> Self {
        guard format == "akshatos-watchlist", version == 1, revision > 0, titles.count <= 50_000,
              Set(titles.map(\.id)).count == titles.count,
              titles.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  && $0.title.count <= 1000 && $0.note.count <= 100_000 && $0.mood.count <= 200 }) else {
            throw PersonalDataError.invalid("That Watchlist file has an invalid format, revision or title.")
        }
        return self
    }
}
struct WatchlistState: Codable, Equatable {
    var version = 1
    var phoneID = UUID()
    var titles: [WatchTitle] = []
    var events: [WatchedEvent] = []
    var sourceID: UUID?
    var metadataRevision = 0
    var eventRevision = 0
    func watched(_ id: UUID) -> Bool {
        events.filter { $0.titleID == id }.max { $0.revision < $1.revision }?.watched ?? false
    }
    func validated() throws -> Self {
        guard version == 1, metadataRevision >= 0, eventRevision >= 0,
              Set(titles.map(\.id)).count == titles.count, Set(events.map(\.id)).count == events.count,
              titles.allSatisfy({ !$0.title.isEmpty && $0.title.count <= 1000 && $0.note.count <= 100_000 }),
              events.allSatisfy({ event in event.revision > 0 && event.revision <= eventRevision && titles.contains(where: { $0.id == event.titleID }) }),
              Set(events.map(\.revision)).count == events.count else {
            throw PersonalDataError.invalid("The Watchlist backup has invalid or duplicate records.")
        }
        return self
    }
    func importCounts(_ transfer: WatchlistTransfer) throws -> (added: Int, changed: Int, removed: Int) {
        _ = try transfer.validated()
        guard sourceID == nil || sourceID == transfer.sourceID else {
            throw PersonalDataError.invalid("This file comes from another Watchlist writer. Keep your current backup and choose the original source.")
        }
        guard transfer.revision > metadataRevision else {
            throw PersonalDataError.invalid("This revision is already imported or older than your current list.")
        }
        var added = 0, changed = 0, removed = 0
        for var title in transfer.titles {
            title.origin = "laptop"
            if let old = titles.first(where: { $0.id == title.id }) {
                guard old.origin != "phone" else { throw PersonalDataError.invalid("An imported title conflicts with a phone-owned title.") }
                if title.deleted && !old.deleted { removed += 1 } else if old != title { changed += 1 }
            } else if !title.deleted { added += 1 }
        }
        return (added, changed, removed)
    }
    mutating func apply(_ transfer: WatchlistTransfer) throws {
        _ = try importCounts(transfer)
        for var title in transfer.titles {
            title.origin = "laptop"
            if let index = titles.firstIndex(where: { $0.id == title.id }) { titles[index] = title }
            else { titles.append(title) }
        }
        sourceID = transfer.sourceID; metadataRevision = transfer.revision
        // Absence never deletes a title; watched events have a separate phone-owned stream.
    }
    mutating func mark(_ id: UUID, watched: Bool, at date: Date) {
        guard titles.contains(where: { $0.id == id && !$0.deleted }) else { return }
        eventRevision += 1
        events.append(WatchedEvent(titleID: id, watched: watched, date: date, revision: eventRevision))
    }
}

struct WatchlistEventsExport: Codable {
    var format = "akshatos-watched-events"
    var version = 1
    var phoneID: UUID
    var revision: Int
    var events: [WatchedEvent]
}
