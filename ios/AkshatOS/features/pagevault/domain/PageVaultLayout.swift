import Foundation

// Page-fitting geometry, expressed as fractions of the page so it needs no graphics types and can be
// reasoned about without a document.
//
// Why this exists: on a phone in portrait, page width binds, and most of a printed page's width is
// margin rather than text. Cropping every page to where its text actually sits makes the text block,
// not the paper, fill the screen. Nothing here clips content: a page whose ink reaches beyond the
// shared text area gets a larger box of its own.

/// Ink bounds as fractions of the page, origin bottom-left, in the range 0...1.
struct PageVaultInkBox: Codable, Equatable {
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    /// A measured page with no ink on it at all.
    static let blank = PageVaultInkBox(minX: 0, minY: 0, maxX: 0, maxY: 0)

    var width: Double { max(0, maxX - minX) }
    var height: Double { max(0, maxY - minY) }
    var isEmpty: Bool { width <= 0 || height <= 0 }

    func contains(_ other: PageVaultInkBox) -> Bool {
        minX <= other.minX && minY <= other.minY && maxX >= other.maxX && maxY >= other.maxY
    }

    func union(_ other: PageVaultInkBox) -> PageVaultInkBox {
        PageVaultInkBox(minX: min(minX, other.minX), minY: min(minY, other.minY),
                        maxX: max(maxX, other.maxX), maxY: max(maxY, other.maxY))
    }

    /// Grown by `amount` on every side, then kept on the page.
    func padded(_ amount: Double) -> PageVaultInkBox {
        PageVaultInkBox(minX: max(0, minX - amount), minY: max(0, minY - amount),
                        maxX: min(1, maxX + amount), maxY: min(1, maxY + amount))
    }
}

/// Where the ink sits on every page of one document, measured once and cached so a book opens
/// already fitted. Raw measurements are kept rather than crop boxes, so the fitting rules can
/// change without measuring the pages again.
struct PageVaultInkSurvey: Codable, Equatable {
    /// Bump when the measurement itself changes, so an older survey is retaken rather than trusted.
    static let currentVersion = 1

    var version: Int
    var pageCount: Int
    /// One entry per page: nil where the page could not be measured, `PageVaultInkBox.blank` for a
    /// page with no ink.
    var boxes: [PageVaultInkBox?]

    init(version: Int = PageVaultInkSurvey.currentVersion, boxes: [PageVaultInkBox?]) {
        self.version = version
        pageCount = boxes.count
        self.boxes = boxes
    }

    func isCurrent(pageCount expected: Int) -> Bool {
        version == PageVaultInkSurvey.currentVersion && pageCount == expected && boxes.count == expected
    }
}

/// Finds the ink on a small grayscale render of one page.
enum PageVaultInkScan {
    /// How much darker than the paper a pixel must be to count as ink. Judged against the page's
    /// own paper rather than pure white, so an off-white or yellowed scan still has margins.
    static let contrast = 48
    /// An edge row or column needs at least this many inked pixels, so a lone speck of dust or
    /// compression noise cannot stretch the box.
    static let minimumMarks = 2

    /// `pixels` is row-major with row 0 at the top, as a bitmap context stores it. Nil when the
    /// buffer does not match its dimensions.
    static func inkBox(pixels: [UInt8], width: Int, height: Int) -> PageVaultInkBox? {
        guard width > 0, height > 0, pixels.count == width * height else { return nil }
        var histogram = [Int](repeating: 0, count: 256)
        for value in pixels { histogram[Int(value)] += 1 }
        // Paper is what most of a page is, so the median brightness stands in for it.
        var seen = 0
        var paper = 255
        for level in 0..<256 {
            seen += histogram[level]
            if seen * 2 >= pixels.count {
                paper = level
                break
            }
        }
        let threshold = paper - contrast
        // A page that is dark nearly everywhere is an image, not text on paper.
        guard threshold > 0 else { return PageVaultInkBox(minX: 0, minY: 0, maxX: 1, maxY: 1) }

        var columns = [Int](repeating: 0, count: width)
        var rows = [Int](repeating: 0, count: height)
        for row in 0..<height {
            let offset = row * width
            for column in 0..<width where Int(pixels[offset + column]) < threshold {
                columns[column] += 1
                rows[row] += 1
            }
        }
        guard let left = columns.firstIndex(where: { $0 >= minimumMarks }),
              let right = columns.lastIndex(where: { $0 >= minimumMarks }),
              let top = rows.firstIndex(where: { $0 >= minimumMarks }),
              let bottom = rows.lastIndex(where: { $0 >= minimumMarks }) else {
            return .blank
        }
        // Row 0 is the top of the bitmap but a PDF page's origin is bottom-left, so rows invert.
        return PageVaultInkBox(minX: Double(left) / Double(width),
                               minY: Double(height - 1 - bottom) / Double(height),
                               maxX: Double(right + 1) / Double(width),
                               maxY: Double(height - top) / Double(height))
    }
}

enum PageVaultCrop {
    /// Breathing room around the text so cropping never shaves glyph edges.
    static let padding = 0.012
    /// Ink covering this much of both dimensions is a scan or full-page image, left as published.
    static let fullBleedExtent = 0.96
    /// Below this much gain on both axes, cropping is not worth changing the page geometry for.
    static let minimumWorthwhileGain = 0.03
    /// With enough pages, the most extreme few per edge are ignored when sizing the shared text
    /// area, so one stray mark cannot widen every page. Pages beyond it get a larger box instead.
    static let outlierFraction = 0.05
    static let outlierMinimumPages = 20

    static func isFullBleed(_ box: PageVaultInkBox) -> Bool {
        box.width >= fullBleedExtent && box.height >= fullBleedExtent
    }

    /// One crop box per page, as fractions of that page's published crop box. Nil leaves the page
    /// exactly as published: a scan, a full-page image, or a page that could not be measured.
    ///
    /// Every ordinary page gets the same size of box, so text stays the same size from page to page.
    /// Facing pages are positioned separately, because printed books and scans often sit off-centre
    /// in opposite directions on left and right pages. A page whose ink reaches beyond that shared
    /// box gets a box grown to contain it, so no page is ever clipped.
    static func cropBoxes(for survey: [PageVaultInkBox?]) -> [PageVaultInkBox?] {
        var parities: [[PageVaultInkBox]] = [[], []]
        for (index, box) in survey.enumerated() {
            guard let box, !box.isEmpty, !isFullBleed(box) else { continue }
            parities[index % 2].append(box)
        }
        let all = parities[0] + parities[1]
        guard !all.isEmpty else { return survey.map { _ in nil } }

        let raw = parities.map { envelope($0.count >= 3 ? $0 : all) }
        let width = raw.map(\.width).max() ?? 0
        let height = raw.map(\.height).max() ?? 0
        let areas = raw.map { sized($0, width: width, height: height).padded(padding) }
        let widest = areas.map(\.width).max() ?? 1
        let tallest = areas.map(\.height).max() ?? 1
        guard 1 - widest >= minimumWorthwhileGain || 1 - tallest >= minimumWorthwhileGain else {
            return survey.map { _ in nil }
        }

        return survey.indices.map { index -> PageVaultInkBox? in
            guard let box = survey[index], !isFullBleed(box) else { return nil }
            let area = areas[index % 2]
            return box.isEmpty ? area : area.union(box.padded(padding))
        }
    }

    /// The text area shared by a set of pages. Extremes are ignored once there are enough pages.
    static func envelope(_ boxes: [PageVaultInkBox]) -> PageVaultInkBox {
        let trim = boxes.count >= outlierMinimumPages ? outlierFraction : 0
        return PageVaultInkBox(minX: quantile(boxes.map(\.minX), trim),
                               minY: quantile(boxes.map(\.minY), trim),
                               maxX: quantile(boxes.map(\.maxX), 1 - trim),
                               maxY: quantile(boxes.map(\.maxY), 1 - trim))
    }

    static func quantile(_ values: [Double], _ fraction: Double) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let position = Int((Double(sorted.count - 1) * fraction).rounded())
        return sorted[min(max(position, 0), sorted.count - 1)]
    }

    /// Resizes a box about its own centre, then slides it back onto the page if that pushed it off.
    static func sized(_ box: PageVaultInkBox, width: Double, height: Double) -> PageVaultInkBox {
        let fittedWidth = min(1, max(0, width))
        let fittedHeight = min(1, max(0, height))
        let minX = min(max(0, (box.minX + box.maxX - fittedWidth) / 2), 1 - fittedWidth)
        let minY = min(max(0, (box.minY + box.maxY - fittedHeight) / 2), 1 - fittedHeight)
        return PageVaultInkBox(minX: minX, minY: minY,
                               maxX: minX + fittedWidth, maxY: minY + fittedHeight)
    }
}
