import Foundation

/// One backup for the whole hub. It asks each module for its own backup and puts them side by side
/// in one folder; restoring checks every part before any module is touched.
///
/// It lives in the app layer because it is the one place allowed to know every feature. Each module
/// keeps owning its data and its own format; this only calls each module's own backup and restore.
@MainActor final class FullBackupService: ObservableObject {
    @Published private(set) var working = false

    /// A checked backup waiting for the user to confirm.
    struct PreparedRestore {
        let source: URL
        let manifest: AkshatOSBackupManifest
        fileprivate var pushups: SquatsBackup?
        fileprivate var liftLog: Data?
        fileprivate var body: URL?
        fileprivate var pageVault: PageVaultStore.PageVaultPreparedRestore?
        /// Every book in the backup is already here with the same PDF.
        fileprivate var pageVaultUpToDate = false

        var titles: [String] { manifest.parts.map(\.title) }
    }

    private let squats: SquatStore
    private let pageVault: PageVaultStore
    private let liftLog: LiftLogStore
    private let bodyLog: BodyLogStore
    private let now: () -> Date
    private let calendar: Calendar
    private let appVersion: String
    private let scratch: URL

    init(squats: SquatStore, pageVault: PageVaultStore, liftLog: LiftLogStore, bodyLog: BodyLogStore,
         now: @escaping () -> Date = Date.init, calendar: Calendar = .current,
         appVersion: String? = nil, scratch: URL? = nil) {
        self.squats = squats
        self.pageVault = pageVault
        self.liftLog = liftLog
        self.bodyLog = bodyLog
        self.now = now
        self.calendar = calendar
        let info = Bundle.main.infoDictionary
        self.appVersion = appVersion ?? "\(info?["CFBundleShortVersionString"] as? String ?? "?") (\(info?["CFBundleVersion"] as? String ?? "?"))"
        self.scratch = scratch ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("AkshatOSFullBackup", isDirectory: true)
    }

    // MARK: - Back up

    /// Builds the backup folder for the system file mover. Every module is included; PageVault
    /// only when it has books, since an empty library has nothing to export.
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
            var parts: [AkshatOSBackupManifest.Part] = []

            await squats.refresh()
            guard squats.storageAvailable else {
                throw AkshatOSBackupError.storage("Pushups could not be read; unlock the phone and try again")
            }
            try squats.makeBackupData()
                .write(to: folder.appendingPathComponent(AkshatOSBackupManifest.Part.pushups.path), options: .atomic)
            parts.append(.pushups)

            liftLog.load()
            guard liftLog.storageAvailable else { throw AkshatOSBackupError.storage("Lift Log could not be read") }
            try liftLog.backupData()
                .write(to: folder.appendingPathComponent(AkshatOSBackupManifest.Part.liftLog.path), options: .atomic)
            parts.append(.liftLog)

            bodyLog.load()
            guard bodyLog.storageAvailable else { throw AkshatOSBackupError.storage("Body could not be read") }
            let body = try bodyLog.stageBackup()
            try files.moveItem(at: body, to: folder.appendingPathComponent(AkshatOSBackupManifest.Part.body.path))
            try? files.removeItem(at: body.deletingLastPathComponent())
            parts.append(.body)

            await pageVault.ensureLoaded()
            if !pageVault.books.isEmpty {
                let library = try await pageVault.prepareExport(includeDocuments: true)
                defer { pageVault.finishExport() }
                try files.moveItem(at: library,
                                   to: folder.appendingPathComponent(AkshatOSBackupManifest.Part.pageVault.path))
                parts.append(.pageVault)
            }

            try AkshatOSBackupManifest(createdAt: now(), appVersion: appVersion, parts: parts).encoded()
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

    /// Reads the backup and checks every part it lists. Nothing changes; one bad part stops the
    /// whole restore before any module is touched.
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
        var prepared = PreparedRestore(source: source, manifest: manifest)

        for part in manifest.parts {
            let location = source.appendingPathComponent(part.path)
            guard (try? location.checkResourceIsReachable()) == true else {
                throw AkshatOSBackupError.missingPart(part.title)
            }
            do {
                switch part {
                case .pushups:
                    prepared.pushups = try squats.prepareRestore(Data(contentsOf: location)).validated()
                case .liftLog:
                    let data = try Data(contentsOf: location)
                    _ = try LiftLogStore.validatedBackup(data)
                    prepared.liftLog = data
                case .body:
                    try bodyLog.checkBackup(at: location)
                    prepared.body = location
                case .pageVault:
                    await pageVault.ensureLoaded()
                    do {
                        prepared.pageVault = try await pageVault.prepareRestore(from: location)
                    } catch PageVaultBackupError.nothingToRestore(let missing) where missing == 0 {
                        prepared.pageVaultUpToDate = true
                    }
                }
            } catch let error as AkshatOSBackupError {
                throw error
            } catch {
                throw AkshatOSBackupError.invalidPart(part.title, reason: error.localizedDescription)
            }
        }
        return prepared
    }

    /// Restores every checked part and says what happened. Pushups, Lift Log and Body are replaced
    /// by the backup; PageVault adds missing books and gives the rest the backup's place and status.
    func restore(_ prepared: PreparedRestore) async -> String {
        working = true
        defer { working = false }
        let source = prepared.source
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        var restored: [String] = []
        var failed: [String] = []
        for part in prepared.manifest.parts {
            switch part {
            case .pushups:
                guard let backup = prepared.pushups else { continue }
                if await squats.restore(backup) {
                    restored.append(part.title)
                    squats.notice = nil // The summary below says the same thing.
                } else {
                    failed.append("\(part.title): \(squats.message ?? "it is busy, try again")")
                }
            case .liftLog:
                guard let data = prepared.liftLog else { continue }
                if liftLog.restoreBackup(data) { restored.append(part.title) }
                else { failed.append("\(part.title): \(liftLog.message ?? "unknown error")") }
                liftLog.message = nil
            case .body:
                guard let location = prepared.body else { continue }
                if bodyLog.restore(from: location) { restored.append(part.title) }
                else { failed.append("\(part.title): \(bodyLog.message ?? "unknown error")") }
                bodyLog.message = nil
            case .pageVault:
                if prepared.pageVaultUpToDate { restored.append("\(part.title) (already up to date)"); continue }
                guard let plan = prepared.pageVault else { continue }
                do {
                    _ = try await pageVault.restore(plan, mode: .replaceMatching)
                    restored.append(part.title)
                } catch {
                    failed.append("\(part.title): \(error.localizedDescription)")
                }
            }
        }

        var lines: [String] = []
        if !restored.isEmpty { lines.append("Restored: \(restored.joined(separator: ", ")).") }
        if !failed.isEmpty { lines.append("Not restored — \(failed.joined(separator: "; ")).") }
        if prepared.pushups != nil { lines.append("Open Pushups and resume any open day to turn reminders back on.") }
        return lines.joined(separator: "\n")
    }
}
