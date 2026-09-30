import Foundation

/// One backup for the whole hub. It asks every registered module for its own backup and puts them
/// side by side in one folder; restoring checks every part before any module is touched.
///
/// It knows no module by name: modules take part through `HubBackupPart`, and `AppServices` lists
/// them. Adding a module to the hub means conforming it and listing it there — nothing here changes.
@MainActor final class FullBackupService: ObservableObject {
    @Published private(set) var working = false

    /// A checked backup waiting for the user to confirm.
    struct PreparedRestore {
        let source: URL
        let manifest: AkshatOSBackupManifest
        fileprivate let restores: [(title: String, restore: HubBackupRestore)]

        var titles: [String] { restores.map(\.title) }
    }

    let parts: [any HubBackupPart]
    private let now: () -> Date
    private let calendar: Calendar
    private let appVersion: String
    private let scratch: URL

    init(parts: [any HubBackupPart], now: @escaping () -> Date = Date.init, calendar: Calendar = .current,
         appVersion: String? = nil, scratch: URL? = nil) {
        // A duplicate id is a programming error that the registry test and CI catch first.
        precondition((try? AkshatOSBackupManifest.checkRegistry(parts.map(\.backupID))) != nil,
                     "Every backup part needs its own backupID")
        self.parts = parts
        self.now = now
        self.calendar = calendar
        let info = Bundle.main.infoDictionary
        self.appVersion = appVersion ?? "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        self.scratch = scratch ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("AkshatOSFullBackup", isDirectory: true)
    }

    // MARK: - Back up

    /// Builds the backup folder for the system file mover. A module with nothing to back up is left
    /// out; a module that cannot be read stops the backup, so it is never silently incomplete.
    func prepareExport() async throws -> URL {
        working = true
        defer { working = false }
        finishExport()
        let folder = scratch.appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(AkshatOSBackupManifest.folderName(for: now(), calendar: calendar),
                                    isDirectory: true)
        let files = FileManager.default
        do {
            try files.createDirectory(at: folder, withIntermediateDirectories: true)
            var entries: [AkshatOSBackupManifest.Entry] = []
            for part in parts {
                let written: String?
                do {
                    written = try await part.writeBackup(into: folder)
                } catch {
                    throw AkshatOSBackupError.storage("\(part.backupTitle): \(error.localizedDescription)")
                }
                guard let name = written else { continue }
                guard AkshatOSBackupManifest.isPlainName(name),
                      !entries.contains(where: { $0.path == name }),
                      (try? folder.appendingPathComponent(name).checkResourceIsReachable()) == true else {
                    throw AkshatOSBackupError.storage("\(part.backupTitle) did not write its backup")
                }
                entries.append(.init(id: part.backupID, title: part.backupTitle, path: name))
            }
            try AkshatOSBackupManifest(createdAt: now(), appVersion: appVersion, parts: entries).encoded()
                .write(to: folder.appendingPathComponent(AkshatOSBackupManifest.fileName), options: .atomic)
            return folder
        } catch {
            try? files.removeItem(at: folder.deletingLastPathComponent())
            if let known = error as? AkshatOSBackupError { throw known }
            throw AkshatOSBackupError.storage(error.localizedDescription)
        }
    }

    /// Clears what was staged once the file mover is done with it, whether it was saved or not.
    func finishExport() {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - Restore

    /// Reads the backup and checks every part it lists. Nothing changes; one bad or unknown part
    /// stops the whole restore before any module is touched.
    func prepareRestore(from source: URL) async throws -> PreparedRestore {
        working = true
        defer { working = false }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let manifestData: Data
        do {
            manifestData = try Data(contentsOf: source.appendingPathComponent(AkshatOSBackupManifest.fileName))
        } catch {
            throw AkshatOSBackupError.notABackup
        }
        let manifest = try AkshatOSBackupManifest.decode(manifestData)

        var restores: [(title: String, restore: HubBackupRestore)] = []
        for entry in manifest.parts {
            guard let part = parts.first(where: { $0.backupID == entry.id }) else {
                throw AkshatOSBackupError.unknownPart(entry.title)
            }
            let location = source.appendingPathComponent(entry.path)
            guard (try? location.checkResourceIsReachable()) == true else {
                throw AkshatOSBackupError.missingPart(part.backupTitle)
            }
            do {
                let restore = try await part.prepareBackupRestore(from: location)
                restores.append((part.backupTitle, restore))
            } catch {
                throw AkshatOSBackupError.invalidPart(part.backupTitle, reason: error.localizedDescription)
            }
        }
        return PreparedRestore(source: source, manifest: manifest, restores: restores)
    }

    /// Applies every checked part and says what happened.
    func restore(_ prepared: PreparedRestore) async -> String {
        working = true
        defer { working = false }
        let source = prepared.source
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        var restored: [String] = []
        var failed: [String] = []
        var notes: [String] = []
        for (title, restore) in prepared.restores {
            switch await restore.apply() {
            case .restored:
                restored.append(title)
                if let note = restore.note { notes.append(note) }
            case .alreadyCurrent:
                restored.append("\(title) (already up to date)")
            case .failed(let reason):
                failed.append("\(title): \(reason)")
            }
        }

        var lines: [String] = []
        if !restored.isEmpty { lines.append("Restored: \(restored.joined(separator: ", ")).") }
        if !failed.isEmpty { lines.append("Not restored — \(failed.joined(separator: "; ")).") }
        return (lines + notes).joined(separator: "\n")
    }
}
