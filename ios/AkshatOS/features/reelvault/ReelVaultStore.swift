import Foundation
import SwiftUI

/// Akshat's own videos with a headline each, and the order the feed shows them in. Every change is
/// saved before the screen shows it; a video is in the library only once its copy is complete,
/// plays, and its record is saved.
@MainActor final class ReelVaultStore: ObservableObject {
    /// Newest first.
    @Published private(set) var videos: [ReelVideo] = []
    @Published private(set) var storageAvailable = false
    /// Imports still copying. The library shows progress while it is above zero.
    @Published private(set) var importing = 0
    @Published var message: String?

    /// A checked backup waiting for the user to confirm.
    struct PreparedRestore {
        let source: URL
        let backup: ReelVaultBackup
        let plan: ReelRestorePlan
    }

    private let repository: any ReelVaultRepository
    private let storage: ReelVaultStorage?
    private let inspector: any ReelVideoInspecting
    private let now: () -> Date
    private let calendar: Calendar
    private var bag = ReelShuffleBag()
    private var loaded = false
    /// Imports run one after another, so two copies of one video cannot both pass the duplicate check.
    private var importTail: Task<Void, Never>?

    init(repository: (any ReelVaultRepository)? = nil, storage: ReelVaultStorage? = nil,
         inspector: (any ReelVideoInspecting)? = nil, now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current) {
        self.repository = repository ?? SwiftDataReelVaultRepository()
        self.storage = storage ?? (try? ReelVaultStorage())
        self.inspector = inspector ?? ReelVideoInspector()
        self.now = now
        self.calendar = calendar
    }

    var totalBytes: Int64 { videos.reduce(0) { $0 + $1.byteCount } }

    func load() {
        guard let storage else {
            storageAvailable = false
            message = "ReelVault storage is unavailable."
            return
        }
        do {
            videos = try repository.load().sorted { $0.importedAt > $1.importedAt }
            storageAvailable = true
            loaded = true
            if importing == 0 {
                storage.clearAbandonedStaging()
                storage.clearOutgoing()
            }
        } catch {
            storageAvailable = false
            message = "Your videos could not be read: \(error.localizedDescription)"
        }
    }

    private func ensureLoaded() {
        if !loaded { load() }
    }

    func video(id: UUID) -> ReelVideo? { videos.first { $0.id == id } }

    /// The app's copy, or nil when its file has gone missing.
    func mediaURL(for video: ReelVideo) -> URL? {
        guard let storage, storage.hasMedia(video.fileName) else { return nil }
        return storage.mediaURL(for: video.fileName)
    }

    /// The next video for the feed: every video once before any repeats.
    func nextInFeed() -> ReelVideo? {
        bag.next(from: videos.map(\.id)).flatMap(video(id:))
    }

    // MARK: - Import

    /// Copies each picked video in. Says once at the end what was added and what was not.
    func importVideos(from sources: [URL], deleteSources: Bool = false) async {
        var added = 0
        var duplicates = 0
        var failures: [String] = []
        for source in sources {
            switch await importVideo(from: source) {
            case .success: added += 1
            case .failure(.duplicate): duplicates += 1
            case .failure(let failure): failures.append(failure.localizedDescription)
            }
            if deleteSources { try? FileManager.default.removeItem(at: source) }
        }
        var lines: [String] = []
        if duplicates > 0 {
            lines.append(duplicates == 1 ? "1 video was already in ReelVault." : "\(duplicates) videos were already in ReelVault.")
        }
        if let first = failures.first {
            lines.append(failures.count == 1 ? first : "\(failures.count) videos could not be added. \(first)")
        }
        if !lines.isEmpty {
            let prefix = added > 0 ? (added == 1 ? "1 video added. " : "\(added) videos added. ") : ""
            message = prefix + lines.joined(separator: " ")
        }
    }

    @discardableResult
    func importVideo(from source: URL) async -> Result<ReelVideo, ReelVaultError> {
        let previous = importTail
        let work = Task { () -> Result<ReelVideo, ReelVaultError> in
            _ = await previous?.value
            return await self.add(from: source)
        }
        importTail = Task { _ = await work.value }
        return await work.value
    }

    private func add(from source: URL) async -> Result<ReelVideo, ReelVaultError> {
        ensureLoaded()
        guard let storage, storageAvailable else { return .failure(.storage("the app's storage is unavailable")) }
        importing += 1
        defer { importing -= 1 }
        let fileExtension = ReelVault.fileExtension(for: source.lastPathComponent)
        let staged: ReelVaultStorage.Staged
        do {
            staged = try await Task.detached(priority: .userInitiated) {
                let scoped = source.startAccessingSecurityScopedResource()
                defer { if scoped { source.stopAccessingSecurityScopedResource() } }
                return try storage.stage(from: source, fileExtension: fileExtension)
            }.value
        } catch {
            return .failure((error as? ReelVaultError) ?? .storage(error.localizedDescription))
        }
        guard !videos.contains(where: { $0.fingerprint == staged.fingerprint }) else {
            storage.discard(staged.url)
            return .failure(.duplicate)
        }
        let duration: Double
        do {
            duration = try await inspector.duration(of: staged.url)
        } catch {
            storage.discard(staged.url)
            return .failure(.notAVideo)
        }
        let id = UUID()
        let video = ReelVideo(id: id, fileName: "\(id.uuidString).\(fileExtension)", headline: "",
                              importedAt: now(), duration: duration, byteCount: staged.byteCount,
                              fingerprint: staged.fingerprint)
        do {
            try storage.promote(staged.url, as: video.fileName)
        } catch {
            return .failure((error as? ReelVaultError) ?? .storage(error.localizedDescription))
        }
        do {
            try repository.save(video)
        } catch {
            try? storage.remove(fileName: video.fileName)
            return .failure(.storage(error.localizedDescription))
        }
        videos.insert(video, at: 0)
        return .success(video)
    }

    // MARK: - Editing

    func setHeadline(_ raw: String, for id: UUID) {
        guard var video = video(id: id) else { return }
        video.headline = ReelVault.headline(raw)
        do {
            try repository.save(video)
            if let index = videos.firstIndex(where: { $0.id == id }) { videos[index] = video }
        } catch {
            message = "The headline could not be saved: \(error.localizedDescription)"
        }
    }

    /// Deletes the app's copy and its record. The original in Photos or Files is not touched.
    func remove(_ id: UUID) {
        guard let video = video(id: id) else { return }
        do {
            try repository.delete(id: id)
            try? storage?.remove(fileName: video.fileName)
            videos.removeAll { $0.id == id }
        } catch {
            message = "The video could not be removed: \(error.localizedDescription)"
        }
    }

    // MARK: - Backup and restore

    /// Stages a folder holding `reelvault.json` and every video, for the system file mover.
    func stageBackup() async throws -> URL {
        ensureLoaded()
        guard let storage, storageAvailable else { throw ReelVaultError.storage("the app's storage is unavailable") }
        guard !videos.isEmpty else { throw ReelVaultError.emptyLibrary }
        let present = videos.filter { storage.hasMedia($0.fileName) }
        let manifest = try ReelVaultBackup(createdAt: now(), videos: present).encoded()
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        let name = String(format: "ReelVault %04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let fileNames = present.map(\.fileName)
        importing += 1
        defer { importing -= 1 }
        return try await Task.detached(priority: .userInitiated) {
            try storage.stageExport(manifest: manifest, name: name, fileNames: fileNames)
        }.value
    }

    /// Clears a staged backup once the file mover is done with it, whether it was saved or not.
    func finishExport() {
        storage?.clearOutgoing()
    }

    /// Reads and checks a backup folder and works out what restoring it would do. Nothing changes.
    func prepareRestore(from source: URL) throws -> PreparedRestore {
        ensureLoaded()
        guard storageAvailable else { throw ReelVaultError.storage("the app's storage is unavailable") }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: source.appendingPathComponent(ReelVaultBackup.manifestName)) else {
            throw ReelVaultError.notABackup
        }
        let backup = try ReelVaultBackup.decode(data)
        let plan = ReelRestorePlan(backup: backup, library: videos)
        guard plan.hasWork else { throw ReelVaultError.nothingToRestore }
        let media = source.appendingPathComponent(ReelVaultBackup.mediaFolder, isDirectory: true)
        for video in plan.additions {
            guard (try? media.appendingPathComponent(video.fileName).checkResourceIsReachable()) == true else {
                throw ReelVaultError.missingVideo(video.headline.isEmpty ? video.fileName : video.headline)
            }
        }
        return PreparedRestore(source: source, backup: backup, plan: plan)
    }

    /// Adds the backup's missing videos and gives videos already here the backup's headline. Every
    /// added file is copied and checked against its size and fingerprint before the library
    /// changes at all, so a damaged backup restores nothing rather than part of a library.
    func restore(_ prepared: PreparedRestore) async throws -> String {
        guard let storage, storageAvailable else { throw ReelVaultError.storage("the app's storage is unavailable") }
        let plan = ReelRestorePlan(backup: prepared.backup, library: videos)
        guard plan.hasWork else { throw ReelVaultError.nothingToRestore }
        importing += 1
        defer { importing -= 1 }
        let source = prepared.source
        let additions = plan.additions
        let staged = try await Task.detached(priority: .userInitiated) { () -> [UUID: URL] in
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            let media = source.appendingPathComponent(ReelVaultBackup.mediaFolder, isDirectory: true)
            var copies: [UUID: URL] = [:]
            do {
                for video in additions {
                    let name = video.headline.isEmpty ? video.fileName : video.headline
                    let copy: ReelVaultStorage.Staged
                    do {
                        copy = try storage.stage(from: media.appendingPathComponent(video.fileName),
                                                 fileExtension: ReelVault.fileExtension(for: video.fileName))
                    } catch {
                        throw ReelVaultError.missingVideo(name)
                    }
                    copies[video.id] = copy.url
                    guard copy.fingerprint == video.fingerprint, copy.byteCount == video.byteCount else {
                        throw ReelVaultError.damagedVideo(name)
                    }
                }
                return copies
            } catch {
                for url in copies.values { storage.discard(url) }
                throw error
            }
        }.value

        var added: [ReelVideo] = []
        do {
            for original in additions {
                guard let url = staged[original.id] else { throw ReelVaultError.storage("a checked copy went missing") }
                var video = original
                // An id or file already used here gets a fresh one; the fingerprint is the identity.
                if videos.contains(where: { $0.id == video.id || $0.fileName == video.fileName }) {
                    video.id = UUID()
                    video.fileName = "\(video.id.uuidString).\(ReelVault.fileExtension(for: original.fileName))"
                }
                try storage.promote(url, as: video.fileName)
                try repository.save(video)
                added.append(video)
            }
        } catch {
            for video in added {
                try? repository.delete(id: video.id)
                try? storage.remove(fileName: video.fileName)
            }
            for url in staged.values { storage.discard(url) }
            throw (error as? ReelVaultError) ?? ReelVaultError.storage(error.localizedDescription)
        }
        videos = (videos + added).sorted { $0.importedAt > $1.importedAt }
        for change in plan.headlineChanges { setHeadline(change.headline, for: change.id) }

        var parts: [String] = []
        if !added.isEmpty { parts.append(added.count == 1 ? "1 video added" : "\(added.count) videos added") }
        if !plan.headlineChanges.isEmpty {
            parts.append(plan.headlineChanges.count == 1 ? "1 headline updated" : "\(plan.headlineChanges.count) headlines updated")
        }
        return parts.joined(separator: ", ") + "."
    }
}
