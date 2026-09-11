import Foundation

// Highlighted passages, kept as PageVault metadata. The PDF file itself is never modified: the
// rectangles below are replayed as in-memory annotations each time a book opens, so a highlight can
// never corrupt the document it came from. Highlights live in the book's own record, which means
// they travel with an export and are deleted with the book without any extra bookkeeping.

/// A rectangle in PDF points. Page coordinates, so trimming a page's margins never moves it.
/// Declared here rather than reusing `CGRect` because the domain layer is Foundation-only.
struct PageVaultRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var isEmpty: Bool { width <= 0 || height <= 0 }
}

struct PageVaultHighlight: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Zero-based page the passage sits on.
    var page: Int
    var text: String
    var createdAt: Date
    /// One rectangle per line of the selection, so a passage spanning several lines marks each of
    /// them rather than one block covering the whole paragraph.
    var rects: [PageVaultRect] = []

    init(id: UUID = UUID(), page: Int, text: String, createdAt: Date, rects: [PageVaultRect] = []) {
        self.id = id
        self.page = page
        self.text = text
        self.createdAt = createdAt
        self.rects = rects
    }

    /// A one-line preview for the highlights list.
    var preview: String {
        text.count <= 140 ? text : String(text.prefix(139)) + "…"
    }

    /// PDF text selections arrive broken at every rendered line, often with a word hyphenated
    /// across two of them. Rejoining is what makes a highlight readable in a list or on an exported
    /// page, and it happens once, when the highlight is made.
    static func tidy(_ raw: String) -> String {
        var joined = ""
        var pendingHyphen = false
        for line in raw.split(whereSeparator: \.isNewline) {
            let piece = line.trimmingCharacters(in: .whitespaces)
            guard !piece.isEmpty else { continue }
            if joined.isEmpty {
                joined = piece
            } else if pendingHyphen {
                joined.removeLast()
                joined += piece
            } else {
                joined += " " + piece
            }
            pendingHyphen = piece.hasSuffix("-")
        }
        return joined.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
