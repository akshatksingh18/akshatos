import Foundation
import SwiftUI

/// Coordinates PageVault: copy-on-import, the library, reading status, bookmarks, reading position,
/// page fitting, and cover generation. File and document work runs off the main actor.
@MainActor final class PageVaultStore: ObservableObject {
    @Published private(set) var library = PageVaultLibrary()
    @Published private(set) var busy = false
    @Published private(set) var storageAvailable = false
    /// Measurement readout kept from the feasibility spike: size, page count, elapsed import time.
    @Published private(set) var lastImportSummary: String?
    @Published private(set) var coverRevision = 0
    /// Page-measurement progress per book, shown while a book is being fitted. Absent once done.
    @Published private(set) var measuringProgress: [UUID: Double] = [:]
    @Published var message: String?
    /// Warm paper is the default: this is meant to read like a book, not like a document viewer.
    @Published var warmPaper: Bool {
        didSet { defaults.set(warmPaper, forKey: "pagevault.warmPaper") }
    }
    /// How far in the reader is zoomed, as a multiple of the whole-page fit. Remembered so a
    /// chosen text size survives page turns, other books and relaunches instead of being redialled.
    @Published var readingZoom: Double {
        didSet {
            let clamped = Self.clampZoom(readingZoom)
            if clamped != readingZoom { readingZoom = clamped; return }
            defaults.set(readingZoom, forKey: "pagevault.readingZoom")
        }
    }

    static let minimumZoom = 1.0
    static let maximumZoom = 4.0

    /// Never below the whole-page fit: zooming further out only shrinks text that is already small.
    static func clampZoom(_ value: Double) -> Double {
        guard value.isFinite else { return minimumZoom }
        return min(max(value, minimumZoom), maximumZoom)
    }

    private let repository: any PageVaultRepository
    private let storage: PageVaultStorage?
    private let documents: any PageVaultDocumentInspecting
    private let now: () -> Date
    private let calendar: Calendar
    private let defaults: UserDefaults
    private var cropCache: [UUID: [PageVaultInkBox?]] = [:]
    private var surveyTasks: [UUID: Task<Void, Never>] = [:]
    private var surveyFailed: Set<UUID> = []

    init(repository: (any PageVaultRepository)? = nil,
         storage: PageVaultStorage? = nil,
         documents: any PageVaultDocumentInspecting = PageVaultDocumentService(),
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current,
         defaults: UserDefaults = .standard) {
        self.repository = repository ?? SwiftDataPageVaultRepository()
        self.storage = storage ?? (try? PageVaultStorage())
        self.documents = documents
        self.now = now
        self.calendar = calendar
        self.defaults = defaults
        self.warmPaper = defaults.object(forKey: "pagevault.warmPaper") as? Bool ?? true
        self.readingZoom = Self.clampZoom(defaults.object(forKey: "pagevault.readingZoom") as? Double
                                          ?? Self.minimumZoom)
    }

    var books: [PageVaultBook] { library.recent }
    var current: PageVaultBook? { library.current }
    func books(with status: PageVaultReadingStatus) -> [PageVaultBook] {
        library.books(with: status)
    }

    var startedBooks: [PageVaultBook] { library.started }
    var unstartedBooks: [PageVaultBook] { library.unstarted }

    func documentURL(for book: PageVaultBook) -> URL? {
        storage?.documentURL(for: book.id)
    }

    func coverURL(for book: PageVaultBook) -> URL? {
        guard let storage, storage.hasCover(for: book.id) else { return nil }
        return storage.coverURL(for: book.id)
    }

    func load() async {
        guard let storage else {
            storageAvailable = false
            message = PageVaultImportFailure.storage("the app container is unavailable").message
            return
        }
        storage.clearAbandonedStaging()
        storage.clearOutgoing()
        do {
            library = try repository.load()
            // Reading streaks are gone; clear any per-day rows an older build left behind.
            try? repository.purgeReadingDays()
            storageAvailable = true
            await ensureCovers()
            // Books imported before page fitting existed are measured in the background.
            Task { await ensureLayouts() }
        } catch {
            storageAvailable = false
            message = "Your library could not be read: \(error.localizedDescription)"
        }
    }

    func importBook(from source: URL) async {
        guard let storage else {
            message = PageVaultImportFailure.storage("the app container is unavailable").message
            return
        }
        busy = true
        defer { busy = false }
        let known = Dictionary(library.books.map { ($0.fingerprint, $0.title) },
                               uniquingKeysWith: { first, _ in first })
        let documents = self.documents
        let importedAt = now()
        do {
            let outcome = try await Task.detached(priority: .userInitiated) {
                try Self.performImport(source: source, storage: storage, documents: documents,
                                       known: known, importedAt: importedAt)
            }.value
            try library.insert(outcome.book)
            try repository.save(outcome.book)
            lastImportSummary = Self.summary(for: outcome)
            await ensureCover(for: outcome.book)
            // Measured right after import, so the book normally opens already fitted.
            let imported = outcome.book
            Task { await ensureLayout(for: imported) }
        } catch let failure as PageVaultImportFailure {
            message = failure.message
        } catch {
            message = PageVaultImportFailure.storage(error.localizedDescription).message
        }
    }

    /// Opening a book only refreshes recency. Reading progress is counted from bookmark to
    /// bookmark, so browsing pages deliberately records nothing.
    func noteOpened(_ book: PageVaultBook) {
        guard var stored = library.books.first(where: { $0.id == book.id }) else { return }
        stored.markOpened(at: now())
        library.update(stored)
        persist(stored)
    }

    /// Bookmarking is the single deliberate signal that reading happened: it moves your place and
    /// claims the book as the one being read.
    func setPlace(_ book: PageVaultBook, page: Int) {
        if book.status != .reading {
            for updated in library.setStatus(.reading, for: book.id, at: now()) { persist(updated) }
        }
        guard let updated = library.setPlace(page: page, for: book.id, at: now()) else { return }
        persist(updated)
    }

    func clearPlace(_ book: PageVaultBook) {
        guard let updated = library.clearPlace(for: book.id, at: now()) else { return }
        persist(updated)
    }

    @discardableResult
    func setStatus(_ status: PageVaultReadingStatus, for book: PageVaultBook) -> Bool {
        let changed = library.setStatus(status, for: book.id, at: now())
        guard !changed.isEmpty else { return false }
        for updated in changed { persist(updated) }
        return true
    }

    func book(id: UUID) -> PageVaultBook? {
        library.books.first { $0.id == id }
    }

    func remove(_ book: PageVaultBook) {
        guard let storage else { return }
        do {
            try repository.delete(id: book.id)
            try storage.remove(id: book.id)
            library.remove(id: book.id)
            cropCache[book.id] = nil
            surveyFailed.remove(book.id)
        } catch {
            message = "That book could not be removed: \(error.localizedDescription)"
        }
    }

    // MARK: - Export and restore

    /// A validated export waiting for the user to confirm. It keeps the picked location so the
    /// confirmed restore can reach the export's PDFs again.
    struct PageVaultPreparedRestore {
        let source: URL
        let backup: PageVaultBackup
        let plan: PageVaultRestorePlan
    }

    /// Stages an export for the system file mover: a folder holding every PDF beside the manifest,
    /// or with `includeDocuments` off, one small JSON file of reading data.
    func prepareExport(includeDocuments: Bool) async throws -> URL {
        guard let storage, storageAvailable else {
            throw PageVaultBackupError.storage("the app container is unavailable")
        }
        guard !library.books.isEmpty else { throw PageVaultBackupError.emptyLibrary }
        busy = true
        defer { busy = false }
        let backup = PageVaultBackup(createdAt: now(), library: library,
                                     includesDocuments: includeDocuments)
        let manifest = try backup.encoded()
        // The local date, formatted here rather than through a locale-dependent formatter.
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        let stamp = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let name = includeDocuments ? "PageVault \(stamp)" : "PageVault reading data \(stamp)"
        var items: [PageVaultStorage.PageVaultExportItem]?
        if includeDocuments {
            items = backup.entries.compactMap { entry in
                entry.file.map { path in
                    PageVaultStorage.PageVaultExportItem(source: storage.documentURL(for: entry.book.id),
                                                         path: path)
                }
            }
        }
        let staged = items
        return try await Task.detached(priority: .userInitiated) {
            try storage.stageExport(manifest: manifest, name: name, documents: staged)
        }.value
    }

    /// Clears a staged export once the file mover is done with it, whether it was saved or not.
    func finishExport() {
        storage?.clearOutgoing()
    }

    /// Reads and validates an export, then works out what restoring it would do. Nothing changes.
    func prepareRestore(from source: URL) async throws -> PageVaultPreparedRestore {
        guard let storage, storageAvailable else {
            throw PageVaultBackupError.storage("the app container is unavailable")
        }
        let read = try await Task.detached(priority: .userInitiated) {
            let scoped = source.startAccessingSecurityScopedResource()
            defer { if scoped { source.stopAccessingSecurityScopedResource() } }
            return try storage.readManifest(at: source)
        }.value
        let backup = try PageVaultBackup.decode(read.data)
        if backup.includesDocuments && read.folder == nil { throw PageVaultBackupError.folderRequired }
        let plan = PageVaultRestorePlan(backup: backup, library: library)
        guard plan.hasWork else {
            throw PageVaultBackupError.nothingToRestore(missingDocuments: plan.missingDocuments.count)
        }
        return PageVaultPreparedRestore(source: read.folder ?? source, backup: backup, plan: plan)
    }

    /// Applies a confirmed restore and returns a summary for the user. Every added book's PDF is
    /// copied and checked against its fingerprint, size and page count before the library changes
    /// at all, so a damaged export restores nothing rather than part of a library.
    func restore(_ prepared: PageVaultPreparedRestore, mode: PageVaultRestoreMode) async throws -> String {
        guard let storage, storageAvailable else {
            throw PageVaultBackupError.storage("the app container is unavailable")
        }
        // Planned again against the library as it is now, in case it changed while confirming.
        let plan = PageVaultRestorePlan(backup: prepared.backup, library: library)
        guard plan.hasWork else {
            throw PageVaultBackupError.nothingToRestore(missingDocuments: plan.missingDocuments.count)
        }
        busy = true
        defer { busy = false }
        let additions = plan.additions
        let source = prepared.source
        let documents = self.documents
        let staged = try await Task.detached(priority: .userInitiated) {
            try Self.stageRestoredDocuments(additions, from: source, storage: storage,
                                            documents: documents)
        }.value

        let result = plan.applied(to: library, backup: prepared.backup, mode: mode, at: now())
        var promoted: [UUID] = []
        do {
            for (backupID, libraryID) in result.additionIDs {
                guard let url = staged[backupID] else {
                    throw PageVaultImportFailure.storage("a verified copy went missing")
                }
                try storage.promote(url, to: libraryID)
                promoted.append(libraryID)
            }
        } catch {
            for id in promoted { try? storage.remove(id: id) }
            for url in staged.values { storage.discard(url) }
            throw PageVaultBackupError.storage((error as? PageVaultImportFailure)?.message
                                               ?? error.localizedDescription)
        }
        for (backupID, url) in staged where result.additionIDs[backupID] == nil {
            storage.discard(url)
        }

        do {
            for id in result.changedBookIDs {
                guard let book = result.library.books.first(where: { $0.id == id }) else { continue }
                try repository.save(book)
            }
        } catch {
            // Whatever did land is real, so show the stored state rather than the intended one.
            library = (try? repository.load()) ?? library
            throw PageVaultBackupError.storage(error.localizedDescription)
        }
        library = result.library
        await ensureCovers()
        Task { await ensureLayouts() }
        return Self.restoreSummary(plan, mode: mode)
    }

    nonisolated private static func stageRestoredDocuments(
        _ additions: [PageVaultBackupEntry], from source: URL, storage: PageVaultStorage,
        documents: any PageVaultDocumentInspecting
    ) throws -> [UUID: URL] {
        guard !additions.isEmpty else { return [:] }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        var staged: [UUID: URL] = [:]
        do {
            for entry in additions {
                guard let file = entry.file else {
                    throw PageVaultBackupError.missingDocument(title: entry.book.title)
                }
                let location = source.appendingPathComponent(file)
                let copy: PageVaultStorage.Staged
                do {
                    copy = try storage.stage(from: location)
                } catch {
                    // Distinguish an absent PDF from one that exists but could not be copied in.
                    if (try? location.checkResourceIsReachable()) == true {
                        throw PageVaultBackupError.storage((error as? PageVaultImportFailure)?.message
                                                           ?? error.localizedDescription)
                    }
                    throw PageVaultBackupError.missingDocument(title: entry.book.title)
                }
                staged[entry.book.id] = copy.url
                let pages = try? documents.inspect(copy.url).pageCount
                guard copy.fingerprint == entry.book.fingerprint,
                      copy.byteCount == entry.book.byteCount,
                      pages == entry.book.pageCount else {
                    throw PageVaultBackupError.documentMismatch(title: entry.book.title)
                }
            }
        } catch {
            for url in staged.values { storage.discard(url) }
            throw error
        }
        return staged
    }

    private static func restoreSummary(_ plan: PageVaultRestorePlan, mode: PageVaultRestoreMode) -> String {
        var lines: [String] = []
        if !plan.additions.isEmpty { lines.append("Added \(bookCount(plan.additions.count)).") }
        if !plan.matches.isEmpty {
            lines.append(mode == .replaceMatching
                         ? "Restored the place and status of \(bookCount(plan.matches.count)) already here."
                         : "Left \(bookCount(plan.matches.count)) already here unchanged.")
        }
        if !plan.missingDocuments.isEmpty {
            lines.append("Skipped \(bookCount(plan.missingDocuments.count)) whose PDF is not in your library.")
        }
        return lines.joined(separator: " ")
    }

    private static func bookCount(_ count: Int) -> String {
        count == 1 ? "1 book" : "\(count) books"
    }

    // MARK: - Page fitting

    /// Per-page crop boxes for a book once its pages have been measured, or nil if they have not.
    /// Measurements are cached on disk, so the boxes are derived at most once per launch per book.
    func pageCrops(for book: PageVaultBook) -> [PageVaultInkBox?]? {
        if let cached = cropCache[book.id] { return cached }
        guard let survey = storage?.readSurvey(for: book.id),
              survey.isCurrent(pageCount: book.pageCount) else { return nil }
        let crops = PageVaultCrop.cropBoxes(for: survey.boxes)
        cropCache[book.id] = crops
        return crops
    }

    /// True when measuring this book failed during this launch, so the reader opens it as published.
    func layoutUnavailable(for book: PageVaultBook) -> Bool {
        surveyFailed.contains(book.id)
    }

    func fittingProgress(for book: PageVaultBook) -> Double {
        measuringProgress[book.id] ?? 0
    }

    /// Measures every book that has not been measured yet, one at a time.
    func ensureLayouts() async {
        for book in library.books { await ensureLayout(for: book) }
    }

    /// Measures where the text sits on every page of a book, once. A caller arriving while that
    /// measurement is already running waits for it instead of starting another.
    func ensureLayout(for book: PageVaultBook) async {
        if let running = surveyTasks[book.id] {
            await running.value
            return
        }
        guard let storage, !surveyFailed.contains(book.id), pageCrops(for: book) == nil else { return }
        let task = Task { await measure(book, storage: storage) }
        surveyTasks[book.id] = task
        await task.value
        surveyTasks[book.id] = nil
    }

    private func measure(_ book: PageVaultBook, storage: PageVaultStorage) async {
        let id = book.id
        let url = storage.documentURL(for: id)
        let documents = self.documents
        let survey = await Task.detached(priority: .utility) {
            documents.inkSurvey(of: url) { fraction in
                Task { @MainActor [weak self] in self?.measuringProgress[id] = fraction }
            }
        }.value
        measuringProgress[id] = nil
        // A book removed while it was being measured must not leave a measurement behind.
        guard library.books.contains(where: { $0.id == id }) else { return }
        if let survey, survey.isCurrent(pageCount: book.pageCount) {
            try? storage.writeSurvey(survey, for: id)
            cropCache[id] = PageVaultCrop.cropBoxes(for: survey.boxes)
        } else {
            surveyFailed.insert(id)
        }
    }

    // MARK: - Covers

    private func ensureCovers() async {
        for book in library.books where coverURL(for: book) == nil {
            await ensureCover(for: book)
        }
    }

    private func ensureCover(for book: PageVaultBook) async {
        guard let storage, !storage.hasCover(for: book.id) else { return }
        let url = storage.documentURL(for: book.id)
        let documents = self.documents
        let data = await Task.detached(priority: .utility) {
            documents.coverPNG(of: url, maxPixel: 600)
        }.value
        guard let data else { return }
        try? storage.writeCover(data, for: book.id)
        coverRevision += 1
    }

    // MARK: - Persistence helpers

    private func persist(_ book: PageVaultBook) {
        do {
            try repository.save(book)
        } catch {
            message = "That change could not be saved: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    private struct ImportOutcome: Sendable {
        var book: PageVaultBook
        var duration: TimeInterval
    }

    nonisolated private static func performImport(
        source: URL, storage: PageVaultStorage, documents: any PageVaultDocumentInspecting,
        known: [String: String], importedAt: Date
    ) throws -> ImportOutcome {
        let began = Date()
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }

        let staged = try storage.stage(from: source)
        if let clash = known[staged.fingerprint] {
            storage.discard(staged.url)
            throw PageVaultImportFailure.duplicate(title: clash)
        }
        let inspection: PageVaultDocumentService.Inspection
        do {
            inspection = try documents.inspect(staged.url)
        } catch {
            storage.discard(staged.url)
            throw error
        }
        let book = PageVaultBook(
            fingerprint: staged.fingerprint,
            title: PageVaultBook.displayTitle(metadataTitle: inspection.metadataTitle,
                                              fileName: source.lastPathComponent),
            pageCount: inspection.pageCount,
            byteCount: staged.byteCount,
            addedAt: importedAt)
        try storage.promote(staged.url, to: book.id)
        return ImportOutcome(book: book, duration: Date().timeIntervalSince(began))
    }

    private static func summary(for outcome: ImportOutcome) -> String {
        let size = ByteCountFormatter.string(fromByteCount: outcome.book.byteCount, countStyle: .file)
        let seconds = String(format: "%.1fs", outcome.duration)
        return "\(size) · \(outcome.book.pageCount) pages · copied in \(seconds)"
    }
}
