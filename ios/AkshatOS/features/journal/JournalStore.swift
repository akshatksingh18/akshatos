import Foundation
import SwiftData
import LocalAuthentication
import UIKit

enum JournalSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [Snapshot.self] }
    @Model final class Snapshot {
        @Attribute(.unique) var key: String
        var payload: Data
        init(payload: Data) { key = "journal"; self.payload = payload }
    }
}

@MainActor final class JournalStore: ObservableObject, HubDayPart {
    @Published private var state = JournalState()
    @Published private(set) var available = false
    @Published private(set) var dayStamp = ""
    @Published private(set) var unlocked = false
    @Published private(set) var lockEnabled: Bool
    @Published var message: String?
    @Published private(set) var unsaved = false
    var onChange: (() -> Void)?
    private var container: ModelContainer?
    private let defaults: UserDefaults
    private(set) var clock: ActivityDayClock
    private let followsSystemZone: Bool
    let photoFolder: URL
    private var failedDraft: JournalEntry?
    private var failedWeekNotes: [String: String] = [:]
    private var accessGeneration = 0
    private var authenticating = false
    private var authContext: LAContext?
    init(container: ModelContainer? = nil, defaults: UserDefaults = .standard, photoFolder: URL? = nil,
         calendar: Calendar? = nil) {
        self.container = container; self.defaults = defaults; clock = ActivityDayClock(calendar: calendar ?? .current); followsSystemZone = calendar == nil
        lockEnabled = defaults.object(forKey: "journal.lock-enabled") as? Bool ?? true
        self.photoFolder = photoFolder ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("JournalPhotos", isDirectory: true)
        unlocked = !lockEnabled
    }
    var isLocked: Bool { lockEnabled && !unlocked }
    var entries: [JournalEntry] { isLocked ? [] : state.entries.sorted { $0.day > $1.day } }
    var today: String { clock.key(Date()) }
    func refreshDay() { if followsSystemZone { clock.calendar.timeZone = .current }; let stamp = today + "|" + clock.calendar.timeZone.identifier; if dayStamp != stamp { dayStamp = stamp } }
    func entry(_ day: String) -> JournalEntry? {
        guard !isLocked else { return nil }
        if failedDraft?.day == day { return failedDraft }
        return state.entries.first { $0.day == day }
    }
    func newEntry(_ day: String) -> JournalEntry { JournalEntry(day: day, zone: clock.calendar.timeZone.identifier) }
    private func context() throws -> ModelContext {
        if container == nil {
            let schema = Schema(versionedSchema: JournalSchemaV1.self)
            container = try ModelContainer(for: schema, configurations: [ModelConfiguration("Journal", schema: schema)])
        }
        return container!.mainContext
    }
    func load() {
        do {
            let rows = try context().fetch(FetchDescriptor<JournalSchemaV1.Snapshot>())
            state = try rows.first.map { try LocalDataCoding.decode(JournalState.self, $0.payload).validated() } ?? JournalState()
            available = true
        } catch { available = false; message = "Journal could not be read. Your entries have not been replaced." }
    }
    @discardableResult private func commit(_ value: JournalState) -> Bool {
        do {
            let checked = try value.validated(), payload = try LocalDataCoding.encode(checked), context = try context()
            do {
                let rows = try context.fetch(FetchDescriptor<JournalSchemaV1.Snapshot>())
                if let row = rows.first { row.payload = payload } else { context.insert(JournalSchemaV1.Snapshot(payload: payload)) }
                try context.save()
            } catch { context.rollback(); throw error }
            state = checked; available = true; onChange?(); return true
        } catch { message = "Journal could not save. Keep this draft open and retry."; return false }
    }
    @discardableResult func save(_ entry: JournalEntry) -> Bool {
        guard !isLocked else { return false }
        if !available { load(); guard available else { return false } }
        guard failedDraft == nil || failedDraft?.day == entry.day else {
            message = "Retry the unsaved entry before changing another day."; return false
        }
        var value = entry; value.updatedAt = Date()
        if !value.hasWriting { value.completedAt = nil }
        var next = state
        if let index = next.entries.firstIndex(where: { $0.day == value.day }) { next.entries[index] = value }
        else { next.entries.append(value) }
        if commit(next) { failedDraft = nil; unsaved = !failedWeekNotes.isEmpty; return true }
        failedDraft = value; unsaved = true; return false
    }
    func retryDraft() {
        guard !isLocked else { return }
        if let draft = failedDraft { _ = save(draft) }
        for (key, text) in failedWeekNotes { setWeekNote(text, week: key) }
    }
    func markDone(_ entry: JournalEntry) {
        guard entry.hasWriting, !isLocked else { return }
        var value = entry; value.completedAt = entry.completedAt == nil ? Date() : nil; _ = save(value)
    }
    func updateFacts(_ facts: JournalDayFacts) {
        guard !isLocked else { return }
        var value = entry(facts.activityDay) ?? newEntry(facts.activityDay)
        value.facts = facts; _ = save(value)
    }
    func weekNote(_ key: String) -> String { isLocked ? "" : (failedWeekNotes[key] ?? state.weeklyNotes[key] ?? "") }
    func setWeekNote(_ text: String, week: String) {
        guard !isLocked, available else { return }
        var next = state; next.weeklyNotes[week] = text
        if commit(next) { failedWeekNotes.removeValue(forKey: week) }
        else { failedWeekNotes[week] = text }
        unsaved = failedDraft != nil || !failedWeekNotes.isEmpty
    }
    func lock() {
        accessGeneration += 1; authContext?.invalidate(); authContext = nil
        if lockEnabled { unlocked = false }
    }
    @discardableResult func authenticate(reason: String = "Open your private Journal") async -> Bool {
        if !isLocked { return true }
        guard !authenticating else { return false }
        authenticating = true; defer { authenticating = false }
        let context = LAContext(), generation = accessGeneration
        authContext = context; defer { authContext = nil }
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = "Set a device passcode to unlock Journal. Entries remain protected."; return false
        }
        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            guard success, generation == accessGeneration else { return false }
            unlocked = true; return true
        } catch { message = "Journal stayed locked. Try unlocking again."; return false }
    }
    func setLockEnabled(_ value: Bool) async {
        guard await authenticate(reason: "Change Journal privacy") else { return }
        defaults.set(value, forKey: "journal.lock-enabled"); lockEnabled = value; unlocked = !value
    }
    func daySummary(_ day: String, at date: Date) -> HubDaySummary {
        // Completion is the only allowed fact outside the access gate; never text, mood or photos.
        let value = state.entries.first { $0.day == day }
        return HubDaySummary(source: "journal", day: day, asOf: date,
            availability: !available ? .unavailable : value == nil ? .noData : .available,
            completed: value?.qualifies == true ? 1 : 0, selected: value == nil ? 0 : 1,
            qualifies: available ? value?.qualifies : nil)
    }
    func addPhoto(_ data: Data, day: String) {
        guard !isLocked, available, data.count <= 20_000_000, let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85) else { message = "That photo could not be opened."; return }
        var value = entry(day) ?? newEntry(day)
        guard value.photos.count < 20 else { message = "This entry already has twenty photos."; return }
        let name = UUID().uuidString + ".jpg", url = photoFolder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: photoFolder, withIntermediateDirectories: true)
            try jpeg.write(to: url, options: [.atomic, .completeFileProtection])
            value.photos.append(name)
            _ = save(value) // Keep media with the in-memory failed draft so Retry remains complete.
        } catch { message = "The photo was not saved. Try again." }
    }
    func photo(_ name: String) -> UIImage? {
        guard !isLocked, LocalDataCoding.plainName(name) else { return nil }
        return UIImage(contentsOfFile: photoFolder.appendingPathComponent(name).path)
    }
    func removePhoto(_ name: String, day: String) {
        guard !isLocked, var value = entry(day) else { return }
        value.photos.removeAll { $0 == name }
        if save(value), LocalDataCoding.plainName(name) { try? FileManager.default.removeItem(at: photoFolder.appendingPathComponent(name)) }
    }
    func onThisDay(_ day: String) -> [JournalEntry] {
        guard !isLocked, let date = clock.date(day) else { return [] }
        let keys = [-1, -12].compactMap { clock.calendar.date(byAdding: .month, value: $0, to: date) }
            .map(clock.calendarKey)
        return entries.filter { keys.contains($0.day) && $0.hasWriting }
    }
    func exportMarkdown(_ day: String) async throws -> URL {
        guard await authenticate(reason: "Export Journal text and photos"), available, !unsaved,
              let entry = entry(day) else { throw PersonalDataError.invalid("Journal export cancelled or the entry is not saved.") }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("JournalExport-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("photos"), withIntermediateDirectories: true)
        do {
            try Data(entry.markdown.utf8).write(to: folder.appendingPathComponent(entry.day + ".md"), options: [.atomic, .completeFileProtection])
            for name in entry.photos {
                try FileManager.default.copyItem(at: photoFolder.appendingPathComponent(name), to: folder.appendingPathComponent("photos").appendingPathComponent(name))
            }
            return folder
        } catch { try? FileManager.default.removeItem(at: folder); throw error }
    }
}

extension JournalStore: HubBackupPart {
    var backupID: String { "journal" }
    var backupTitle: String { "Journal" }
    func writeBackup(into folder: URL) async throws -> String? {
        if !available { load() }; guard available, !unsaved else { throw PersonalDataError.invalid("Save the Journal draft before exporting.") }
        if state.entries.isEmpty && state.weeklyNotes.isEmpty { return nil }
        guard await authenticate(reason: "Include Journal in the full backup") else { throw PersonalDataError.invalid("Journal authentication cancelled. The full backup was stopped.") }
        let destination = folder.appendingPathComponent("journal", isDirectory: true)
        try FileManager.default.createDirectory(at: destination.appendingPathComponent("photos"), withIntermediateDirectories: true)
        try LocalDataCoding.encode(state).write(to: destination.appendingPathComponent("journal.json"), options: [.atomic, .completeFileProtection])
        for name in Set(state.entries.flatMap(\.photos)) {
            try FileManager.default.copyItem(at: photoFolder.appendingPathComponent(name), to: destination.appendingPathComponent("photos").appendingPathComponent(name))
        }
        return "journal"
    }
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore {
        guard await authenticate(reason: "Restore private Journal entries") else { throw PersonalDataError.invalid("Journal restore cancelled.") }
        let files = FileManager.default
        let json = item.appendingPathComponent("journal.json")
        for directory in [item, item.appendingPathComponent("photos")] {
            let info = try directory.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
            guard info.isDirectory == true, info.isSymbolicLink != true else { throw PersonalDataError.invalid("Journal backup folders must be ordinary folders.") }
        }
        let info = try json.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard info.isRegularFile == true, info.isSymbolicLink != true, (info.fileSize ?? Int.max) <= 25_000_000 else { throw PersonalDataError.invalid("Invalid Journal document.") }
        let checked = try LocalDataCoding.decode(JournalState.self, Data(contentsOf: json)).validated()
        // Capture validated bytes while the selected folder is still security-scoped. The restore
        // confirmation may happen after access ends or the external provider changes its file.
        let stage = JournalRestoreFiles()
        try files.createDirectory(at: stage.url, withIntermediateDirectories: true)
        for name in Set(checked.entries.flatMap(\.photos)) {
            let url = item.appendingPathComponent("photos").appendingPathComponent(name)
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true, (values.fileSize ?? Int.max) <= 20_000_000 else { throw PersonalDataError.invalid("Journal photo is missing or invalid.") }
            let data = try Data(contentsOf: url)
            guard UIImage(data: data) != nil else { throw PersonalDataError.invalid("Journal photo cannot be decoded.") }
            try data.write(to: stage.url.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
        }
        return HubBackupRestore(note: "Journal text and photos will be replaced. Exported files are not encrypted by the Journal screen lock.") { [self, stage] in
            guard !isLocked else { return .failed("Unlock Journal again before restoring.") }
            let files = FileManager.default, staging = photoFolder.deletingLastPathComponent().appendingPathComponent("Journal-stage-" + UUID().uuidString)
            let recovery = photoFolder.deletingLastPathComponent().appendingPathComponent("Journal-preimage-" + UUID().uuidString)
            var movedOld = false, installedNew = false
            do {
                try files.createDirectory(at: staging, withIntermediateDirectories: true)
                for name in Set(checked.entries.flatMap(\.photos)) {
                    try files.copyItem(at: stage.url.appendingPathComponent(name), to: staging.appendingPathComponent(name))
                    try files.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: staging.appendingPathComponent(name).path)
                }
                if files.fileExists(atPath: photoFolder.path) { try files.moveItem(at: photoFolder, to: recovery); movedOld = true }
                try files.moveItem(at: staging, to: photoFolder); installedNew = true
                guard commit(checked) else { throw PersonalDataError.invalid(message ?? "Journal restore failed.") }
                failedDraft = nil; failedWeekNotes = [:]; unsaved = false
                if movedOld { try? files.removeItem(at: recovery) }
                return .restored
            } catch {
                if installedNew { try? files.removeItem(at: photoFolder) }
                if movedOld {
                    do { try files.moveItem(at: recovery, to: photoFolder) }
                    catch { return .failed("Journal restore stopped. Existing photos are preserved at \(recovery.lastPathComponent); keep the backup and contact support before retrying.") }
                }
                try? files.removeItem(at: staging)
                return .failed(error.localizedDescription)
            }
        }
    }
}

private final class JournalRestoreFiles {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("Journal-validated-" + UUID().uuidString)
    deinit { try? FileManager.default.removeItem(at: url) }
}
