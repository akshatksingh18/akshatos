import Foundation

// Page-layout geometry, expressed as fractions of the page so it needs no graphics types and can
// be reasoned about without a document.
//
// Why this exists: on a phone in portrait, page width is the binding constraint. A 612pt-wide page
// shown in ~390pt of screen can only ever be drawn at ~0.64x, which is why printed 11pt body text
// arrives as unreadable ~7pt. Most of that width is margin, not text. Trimming the margin raises
// the achievable scale toward 0.83x without any zooming or horizontal panning, which is the largest
// automatic gain available for fixed-layout PDFs.

/// Ink bounds as fractions of the page, origin bottom-left, in the range 0...1.
struct PageVaultInkBox: Equatable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    var width: Double { max(0, maxX - minX) }
    var height: Double { max(0, maxY - minY) }
    var isEmpty: Bool { width <= 0 || height <= 0 }
}

enum PageVaultCrop {
    /// Never trim more than this fraction from any one side. Sampling cannot prove that every page
    /// keeps its content inside the sampled bounds, so the cap limits how badly a wide figure on an
    /// unsampled page can be clipped. Roughly one printed inch on a letter page.
    static let maxSideInset = 0.12
    /// Breathing room left around the text so trimming does not shave glyph edges.
    static let padding = 0.012
    /// Below this much gain, cropping is not worth changing the page geometry for.
    static let minimumWorthwhileGain = 0.03

    /// Unions the sampled ink boxes, pads them, and clamps each side to `maxSideInset`.
    /// Returns nil when cropping would gain nothing — a scanned page whose ink covers the sheet,
    /// or a document already trimmed tight.
    static func cropBox(from samples: [PageVaultInkBox]) -> PageVaultInkBox? {
        let usable = samples.filter { !$0.isEmpty }
        guard !usable.isEmpty else { return nil }

        var box = PageVaultInkBox(
            minX: usable.map(\.minX).min()!,
            minY: usable.map(\.minY).min()!,
            maxX: usable.map(\.maxX).max()!,
            maxY: usable.map(\.maxY).max()!)

        box.minX = max(0, box.minX - padding)
        box.minY = max(0, box.minY - padding)
        box.maxX = min(1, box.maxX + padding)
        box.maxY = min(1, box.maxY + padding)

        box.minX = min(box.minX, maxSideInset)
        box.minY = min(box.minY, maxSideInset)
        box.maxX = max(box.maxX, 1 - maxSideInset)
        box.maxY = max(box.maxY, 1 - maxSideInset)

        guard box.width > 0, box.height > 0 else { return nil }
        // Gain is measured on width alone: width is what limits scale in portrait.
        guard 1 - box.width >= minimumWorthwhileGain else { return nil }
        return box
    }

    /// Which pages to sample. Spread across the document so a title page or plate section cannot
    /// alone decide the crop, while keeping the cost to a handful of renders on a long book.
    static func samplePageIndices(pageCount: Int, limit: Int = 5) -> [Int] {
        guard pageCount > 0 else { return [] }
        guard pageCount > limit else { return Array(0..<pageCount) }
        // Skip the very first page: covers and title pages rarely share the body's margins.
        let first = min(1, pageCount - 1)
        let span = pageCount - 1 - first
        guard span > 0 else { return [first] }
        return (0..<limit).map { first + Int((Double($0) / Double(limit - 1)) * Double(span)) }
    }
}
