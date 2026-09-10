import Foundation

// Pure domain types: no PDFKit, SwiftData, SwiftUI, or file-system side effects. The feasibility
// spike keeps every decision that can be reasoned about without a document in this layer.

struct PageVaultBook: Codable, Identifiable, Equatable {
    var id = UUID()
    /// Streamed content digest. Duplicate imports are detected by this, never by display name.
    var fingerprint: String
    var title: String
    var pageCount: Int
    var byteCount: Int64
    var addedAt: Date
    var lastOpenedAt: Date? = nil
    var currentPage = 0

    /// A persisted page can outlive the page count it was valid for, so every read clamps.
    func resolvedPage(_ requested: Int? = nil) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(requested ?? currentPage, 0), pageCount - 1)
    }

    var progressLabel: String {
        pageCount > 0 ? "\(resolvedPage() + 1) / \(pageCount)" : "No pages"
    }

    mutating func remember(page: Int, at date: Date) {
        currentPage = resolvedPage(page)
        lastOpenedAt = date
    }

    /// PDF metadata titles are frequently blank, whitespace, or a leftover file path.
    static func displayTitle(metadataTitle: String?, fileName: String) -> String {
        let candidates = [metadataTitle, fileName]
        for candidate in candidates {
            let trimmed = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let withoutExtension = trimmed.lowercased().hasSuffix(".pdf")
                ? String(trimmed.dropLast(4)).trimmingCharacters(in: .whitespaces) : trimmed
            if !withoutExtension.isEmpty { return withoutExtension }
        }
        return "Untitled document"
    }
}

struct PageVaultLibrary: Codable, Equatable {
    var books: [PageVaultBook] = []

    /// Most recently read first, falling back to import time for books never opened.
    var recent: [PageVaultBook] {
        books.sorted { ($0.lastOpenedAt ?? $0.addedAt) > ($1.lastOpenedAt ?? $1.addedAt) }
    }

    func existing(fingerprint: String) -> PageVaultBook? {
        books.first { $0.fingerprint == fingerprint }
    }

    mutating func insert(_ book: PageVaultBook) throws {
        if let clash = existing(fingerprint: book.fingerprint) {
            throw PageVaultImportFailure.duplicate(title: clash.title)
        }
        books.append(book)
    }

    mutating func update(_ book: PageVaultBook) {
        guard let index = books.firstIndex(where: { $0.id == book.id }) else { return }
        books[index] = book
    }

    @discardableResult
    mutating func remove(id: UUID) -> PageVaultBook? {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return nil }
        return books.remove(at: index)
    }
}

enum PageVaultImportFailure: Error, Equatable {
    case unreadable
    case passwordProtected
    case noPages
    case duplicate(title: String)
    case storage(String)

    /// User-facing text. The spike must fail visibly rather than leave a false library entry.
    var message: String {
        switch self {
        case .unreadable:
            return "That file could not be opened as a PDF."
        case .passwordProtected:
            return "That PDF is password protected, so it cannot be added."
        case .noPages:
            return "That PDF reported no pages."
        case .duplicate(let title):
            return "Already in your library as \"\(title)\"."
        case .storage(let reason):
            return "Could not save a copy: \(reason)"
        }
    }
}

struct PageVaultOutlineNode: Equatable {
    /// Stable index path, so rows keep identity without generating fresh UUIDs on every traversal.
    var id: String
    var title: String
    var page: Int?
    var children: [PageVaultOutlineNode] = []
}

struct PageVaultOutlineRow: Equatable, Identifiable {
    var id: String
    var title: String
    var page: Int?
    var level: Int
}

extension PageVaultOutlineNode {
    /// Depth-first flattening that preserves hierarchy as an indent level.
    static func rows(_ nodes: [PageVaultOutlineNode], level: Int = 0) -> [PageVaultOutlineRow] {
        nodes.flatMap { node in
            [PageVaultOutlineRow(id: node.id, title: node.title, page: node.page, level: level)]
                + rows(node.children, level: level + 1)
        }
    }
}
