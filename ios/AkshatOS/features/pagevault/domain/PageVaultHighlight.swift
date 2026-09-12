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

    /// True when two bands sit on the same line of text and cover some of the same words.
    ///
    /// This is what decides whether a selection is touching an existing mark. Vertical overlap
    /// alone is not enough: bands from neighbouring lines routinely touch by a fraction of a
    /// point, and treating those as the same line would make a selection absorb the line above it.
    func sameBand(as other: PageVaultRect) -> Bool {
        sharesLine(with: other) && overlapsHorizontally(other)
    }

    /// Overlapping by more than half the shorter band is what separates "the same line of text"
    /// from "the line below it, touching".
    func sharesLine(with other: PageVaultRect) -> Bool {
        let overlap = Swift.min(y + height, other.y + other.height) - Swift.max(y, other.y)
        guard overlap > 0 else { return false }
        return overlap > Swift.min(height, other.height) / 2
    }

    func overlapsHorizontally(_ other: PageVaultRect) -> Bool {
        x < other.x + other.width && other.x < x + width
    }

    /// The smallest band containing both. Used to fold two bands over the same line into one, so
    /// the shared words are never drawn twice.
    func union(_ other: PageVaultRect) -> PageVaultRect {
        let minX = Swift.min(x, other.x)
        let minY = Swift.min(y, other.y)
        let maxX = Swift.max(x + width, other.x + other.width)
        let maxY = Swift.max(y + height, other.y + other.height)
        return PageVaultRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
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

    /// True when this mark covers any of the given page area.
    ///
    /// Identity is geometric, not textual. Two selections over the same words are the same mark
    /// even when their captured text differs by a word, which is the whole reason a slightly wider
    /// selection used to stack a second mark on top of the first.
    func covers(_ others: [PageVaultRect]) -> Bool {
        rects.contains { rect in others.contains { rect.sameBand(as: $0) } }
    }

    /// Folds line bands so that no two of them cover the same words.
    ///
    /// Concatenating the bands of two overlapping marks would draw the shared words twice, and PDF
    /// highlight annotations composite — which is exactly what made a re-marked passage look darker
    /// than the rest of it. Bands on different lines are left alone, so a paragraph stays one band
    /// per line rather than becoming a single block over its indents.
    static func fold(_ rects: [PageVaultRect]) -> [PageVaultRect] {
        var folded: [PageVaultRect] = []
        for rect in rects where !rect.isEmpty {
            var merged = rect
            var untouched: [PageVaultRect] = []
            for kept in folded {
                if kept.sameBand(as: merged) {
                    merged = kept.union(merged)
                } else {
                    untouched.append(kept)
                }
            }
            folded = untouched + [merged]
        }
        return folded
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
