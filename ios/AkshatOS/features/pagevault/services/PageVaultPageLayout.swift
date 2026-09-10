import CoreGraphics
import Foundation
import PDFKit

/// Measures where the ink actually sits on a page and trims the surrounding margin, so the text
/// block — not the paper — is what gets scaled to the screen width.
struct PageVaultPageLayout {
    /// Longest edge of the sampling bitmap. Small on purpose: this only needs to find the edges of
    /// the text block, not render anything legible.
    static let sampleExtent: CGFloat = 200
    /// Anything lighter than this counts as paper rather than ink, so JPEG noise and faint scan
    /// backgrounds do not defeat the measurement.
    static let inkThreshold: UInt8 = 236

    /// Trims every page to the sampled text block. Returns true when a crop was applied.
    /// Sampled rather than per-page so a long book costs a handful of renders, and capped by
    /// `PageVaultCrop` so an unsampled wide figure cannot be badly clipped.
    @discardableResult
    func applyCrop(to document: PDFDocument) -> Bool {
        let indices = PageVaultCrop.samplePageIndices(pageCount: document.pageCount)
        let samples = indices.compactMap { index -> PageVaultInkBox? in
            guard let page = document.page(at: index) else { return nil }
            return inkBox(of: page)
        }
        guard let crop = PageVaultCrop.cropBox(from: samples) else { return false }

        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let box = page.bounds(for: .mediaBox)
            guard box.width > 0, box.height > 0 else { continue }
            page.setBounds(CGRect(x: box.minX + box.width * crop.minX,
                                  y: box.minY + box.height * crop.minY,
                                  width: box.width * crop.width,
                                  height: box.height * crop.height),
                           for: .cropBox)
        }
        return true
    }

    /// Renders the page small and grayscale, then finds the bounding box of non-paper pixels.
    func inkBox(of page: PDFPage) -> PageVaultInkBox? {
        let box = page.bounds(for: .mediaBox)
        guard box.width > 0, box.height > 0 else { return nil }
        let scale = Self.sampleExtent / max(box.width, box.height)
        let width = max(1, Int(box.width * scale))
        let height = max(1, Int(box.height * scale))

        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let base = buffer.baseAddress,
                  let context = CGContext(data: base, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue)
            else { return false }
            context.setFillColor(gray: 1, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            context.scaleBy(x: CGFloat(width) / box.width, y: CGFloat(height) / box.height)
            context.translateBy(x: -box.minX, y: -box.minY)
            page.draw(with: .mediaBox, to: context)
            return true
        }
        guard drawn else { return nil }

        var minX = width, minY = height, maxX = -1, maxY = -1
        for row in 0..<height {
            let offset = row * width
            for column in 0..<width where pixels[offset + column] < Self.inkThreshold {
                if column < minX { minX = column }
                if column > maxX { maxX = column }
                if row < minY { minY = row }
                if row > maxY { maxY = row }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }

        // The bitmap's origin is top-left and a PDF page's is bottom-left, so the rows invert.
        return PageVaultInkBox(minX: Double(minX) / Double(width),
                               minY: Double(height - 1 - maxY) / Double(height),
                               maxX: Double(maxX + 1) / Double(width),
                               maxY: Double(height - minY) / Double(height))
    }
}
