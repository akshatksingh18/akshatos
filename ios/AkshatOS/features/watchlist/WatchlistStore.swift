import Foundation
import SwiftData

enum WatchlistSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Snapshot.self] }
    @Model final class Snapshot {
        @Attribute(.unique) var key: String
        var payload: Data
        init(payload: Data) { key = "watchlist"; self.payload = payload }
    }
}

@MainActor final class WatchlistStore: ObservableObject {
    @Published private(set) var state = WatchlistState()
    @Published private(set) var available = false
    @Published var message: String?
    @Published var pendingImport: WatchlistTransfer?
    @Published private(set) var importDescription = ""
    private var container: ModelContainer?
    init(container: ModelContainer? = nil) { self.container = container }
    func add(title: String, mood: String, kind: String, note: String = "", pick: Bool = false) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        var next = state
        next.titles.append(WatchTitle(title: title, kind: kind, mood: mood.isEmpty ? "Any mood" : mood, note: note, pick: pick))
        _ = commit(next)
    }
    func mark(_ id: UUID, watched: Bool) { var next = state; next.mark(id, watched: watched, at: Date()); _ = commit(next) }
    func update(_ title: WatchTitle) {
        guard title.origin == "phone", let index = state.titles.firstIndex(where: { $0.id == title.id }) else { return }
        var next = state; next.titles[index] = title; _ = commit(next)
    }
    func preview(_ data: Data) {
        do {
            if !available { load() }; guard available else { return }
            let transfer = try LocalDataCoding.decode(WatchlistTransfer.self, data).validated()
            let counts = try state.importCounts(transfer)
            pendingImport = transfer
            importDescription = "\(counts.added) new, \(counts.changed) changed, \(counts.removed) explicitly removed. Watched history stays on this phone."
        } catch { pendingImport = nil; message = error.localizedDescription }
    }
    func applyImport() {
        guard let transfer = pendingImport else { return }
        do {
            var next = state; try next.apply(transfer)
            // One fixed local preimage, never a cloud write. A failed recovery save stops the import.
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WatchlistRecovery", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try LocalDataCoding.encode(state).write(to: folder.appendingPathComponent("before-import.json"),
                                                     options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            if commit(next) { pendingImport = nil }
        } catch { message = "Import stopped: \(error.localizedDescription)" }
    }
    func rollbackImport() {
        do {
            let file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("WatchlistRecovery/before-import.json")
            let previous = try LocalDataCoding.decode(WatchlistState.self, Data(contentsOf: file)).validated()
            var next = previous
            // Reversing a metadata import must not erase subsequent watched events.
            for title in state.titles where !next.titles.contains(where: { $0.id == title.id }) {
                var retained = title
                if retained.origin == "laptop" { retained.deleted = true }
                next.titles.append(retained)
            }
            for title in state.titles where title.origin == "phone" {
                if let i = next.titles.firstIndex(where: { $0.id == title.id }) { next.titles[i] = title }
            }
            next.events = state.events; next.eventRevision = state.eventRevision; next.phoneID = state.phoneID
            _ = commit(next)
        } catch { message = "The previous import could not be restored: \(error.localizedDescription)" }
    }
    func watchedExport() throws -> Data {
        guard available else { throw PersonalDataError.invalid("Watchlist cannot be read.") }
        // Persist an otherwise empty phone identity before returning a reusable event stream.
        guard commit(state) else { throw PersonalDataError.invalid(message ?? "Watchlist could not be saved.") }
        return try LocalDataCoding.encode(WatchlistEventsExport(phoneID: state.phoneID,
            revision: state.eventRevision, events: state.events))
    }
    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: WatchlistSchemaV1.self)
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Watchlist", schema: schema)])
        }
        return container!.mainContext
    }
    func load() {
        do {
            let rows = try context().fetch(FetchDescriptor<WatchlistSchemaV1.Snapshot>())
            state = try rows.first.map { try LocalDataCoding.decode(WatchlistState.self, $0.payload).validated() } ?? WatchlistState()
            available = true
        } catch { available = false; message = "Watchlist could not be read. Your data has not been replaced: \(error.localizedDescription)" }
    }
    @discardableResult func commit(_ value: WatchlistState, replacingUnavailable: Bool = false) -> Bool {
        guard available || replacingUnavailable else { message = "Local data is unavailable. Retry loading before making changes."; return false }
        do {
            let checked = try value.validated(), payload = try LocalDataCoding.encode(checked), context = try context()
            do {
                let rows = try context.fetch(FetchDescriptor<WatchlistSchemaV1.Snapshot>())
                if let row = rows.first { row.payload = payload } else { context.insert(WatchlistSchemaV1.Snapshot(payload: payload)) }
                try context.save()
            } catch { context.rollback(); throw error }
            state = checked; available = true; return true
        } catch { message = "Watchlist was not saved: \(error.localizedDescription)"; return false }
    }
}

extension WatchlistStore: HubBackupPart {
    var backupID: String { "watchlist" }
    var backupTitle: String { "Watchlist" }
    func writeBackup(into folder: URL) async throws -> String? {
        if !available { load() }; guard available else { throw PersonalDataError.invalid("Watchlist cannot be read.") }
        try LocalDataCoding.encode(state).write(to: folder.appendingPathComponent("watchlist.json"), options: .atomic)
        return "watchlist.json"
    }
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        let checked = try LocalDataCoding.decode(WatchlistState.self, Data(contentsOf: item)).validated()
        return HubBackupRestore { [self] in commit(checked, replacingUnavailable: true) ? .restored : .failed(message ?? "Watchlist restore failed") }
    }
}
