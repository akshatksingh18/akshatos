import Foundation
import PDFKit

/// Reads each page's text and hands it to `PageVaultSearch`. Runs on its own `PDFDocument`, never
/// the one on screen, because PDFKit documents are not safe to share across threads.
///
/// A scanned book has no text layer, so it simply yields nothing: PageVault does not OCR.
enum PageVaultSearchService {
    static func search(_ query: String, in url: URL,
                       isCancelled: () -> Bool = { false }) -> [PageVaultSearchHit] {
        guard PageVaultSearch.isSearchable(query),
              let document = PDFDocument(url: url), !document.isLocked else { return [] }
        var hits: [PageVaultSearchHit] = []
        for index in 0..<document.pageCount {
            if isCancelled() { return [] }
            guard hits.count < PageVaultSearch.maximumResults else { break }
            guard let text = document.page(at: index)?.string, !text.isEmpty else { continue }
            hits += PageVaultSearch.hits(in: text, page: index, query: query,
                                         limit: PageVaultSearch.maximumResults - hits.count)
        }
        return hits
    }
}

/// A cancellation signal that can cross into a detached task, which does not inherit the caller's.
/// Typing the next letter should stop the search already running.
final class PageVaultCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
