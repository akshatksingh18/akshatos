import Foundation
import SwiftUI

/// Coordinates the PageVault feasibility spike: copy-on-import, the local library, reading
/// position, and outline lookup. Long file and document work runs off the main actor.
@MainActor final class PageVaultStore: ObservableObject {
    @Published private(set) var library = PageVaultLibrary()
    @Published private(set) var busy = false
    @Published private(set) var storageAvailable = false
    /// Phase-2 measurement readout: size, page count, and elapsed import time.
    @Published private(set) var lastImportSummary: String?
    @Published var message: String?

    private let repository: any PageVaultRepository
    private let storage: PageVaultStorage?
    private let documents: any PageVaultDocumentInspecting
    private let now: () -> Date

    init(repository: (any PageVaultRepository)? = nil,
         storage: PageVaultStorage? = nil,
         documents: any PageVaultDocumentInspecting = PageVaultDocumentService(),
         now: @escaping () -> Date = Date.init) {
        self.repository = repository ?? SwiftDataPageVaultRepository()
        self.storage = storage ?? (try? PageVaultStorage())
        self.documents = documents
        self.now = now
    }

    var books: [PageVaultBook] { library.recent }

    func documentURL(for book: PageVaultBook) -> URL? {
        storage?.documentURL(for: book.id)
    }

    func load() async {
        guard let storage else {
            storageAvailable = false
            message = PageVaultImportFailure.storage("the app container is unavailable").message
            return
        }
        storage.clearAbandonedStaging()
        do {
            library = try repository.load()
            storageAvailable = true
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
        } catch let failure as PageVaultImportFailure {
            message = failure.message
        } catch {
            message = PageVaultImportFailure.storage(error.localizedDescription).message
        }
    }

    func remember(_ book: PageVaultBook, page: Int) {
        guard var stored = library.books.first(where: { $0.id == book.id }) else { return }
        let resolved = stored.resolvedPage(page)
        guard resolved != stored.currentPage || stored.lastOpenedAt == nil else { return }
        stored.remember(page: resolved, at: now())
        library.update(stored)
        do {
            try repository.save(stored)
        } catch {
            message = "Your place could not be saved: \(error.localizedDescription)"
        }
    }

    func remove(_ book: PageVaultBook) {
        guard let storage else { return }
        do {
            try repository.delete(id: book.id)
            try storage.remove(id: book.id)
            library.remove(id: book.id)
        } catch {
            message = "That book could not be removed: \(error.localizedDescription)"
        }
    }

    /// Outline traversal can be slow on a large document, so it never runs on the main actor.
    func outline(for book: PageVaultBook) async -> [PageVaultOutlineNode] {
        guard let url = documentURL(for: book) else { return [] }
        let documents = self.documents
        return await Task.detached(priority: .userInitiated) {
            documents.outline(of: url)
        }.value
    }

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
