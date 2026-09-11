import Foundation

// Searching a book's text. The matching and the readable snippet around each match are pure logic,
// so they are tested without a document; PDFKit only supplies each page's text.

struct PageVaultSearchHit: Equatable, Identifiable {
    /// Page plus offset is stable, which the results list needs and a random id would not give.
    var id: String { "\(page)#\(offset)" }
    /// Zero-based page the match sits on.
    var page: Int
    /// Character offset of the match within that page's text.
    var offset: Int
    var snippet: String
}

enum PageVaultSearch {
    /// Characters kept either side of a match, enough to recognise the sentence it came from.
    static let context = 60
    /// A reader scanning results does not need thousands; stopping also keeps a long book quick.
    static let maximumResults = 200
    /// One letter matches almost everything, which is noise rather than a search.
    static let minimumQueryLength = 2

    static func isSearchable(_ query: String) -> Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumQueryLength
    }

    /// Every match on one page, as display-ready hits. Case- and diacritic-insensitive, which is
    /// what a search box is expected to do.
    static func hits(in text: String, page: Int, query: String, limit: Int) -> [PageVaultSearchHit] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard limit > 0, isSearchable(needle), !text.isEmpty else { return [] }
        var results: [PageVaultSearchHit] = []
        var cursor = text.startIndex
        while results.count < limit,
              let found = text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive],
                                     range: cursor..<text.endIndex) {
            let offset = text.distance(from: text.startIndex, to: found.lowerBound)
            let length = text.distance(from: found.lowerBound, to: found.upperBound)
            results.append(PageVaultSearchHit(page: page, offset: offset,
                                              snippet: snippet(from: text, at: offset, length: length)))
            cursor = found.upperBound
        }
        return results
    }

    /// A one-line extract around the match, with ellipses where the page text carries on.
    static func snippet(from text: String, at offset: Int, length: Int) -> String {
        let characters = Array(text)
        guard offset >= 0, length > 0, offset + length <= characters.count else { return "" }
        let start = max(0, offset - context)
        let end = min(characters.count, offset + length + context)
        var piece = String(characters[start..<end])
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        if start > 0 { piece = "…" + piece }
        if end < characters.count { piece += "…" }
        return piece
    }
}
