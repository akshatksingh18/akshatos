import CoreGraphics
import Foundation
import PDFKit

/// Measures where the ink sits on each page and applies the crop boxes `PageVaultCrop` derives, so
/// the text block — not the paper — is what fills the screen.
struct PageVaultPageLayout {
    /// Longest edge of the measuring bitmap. Small on purpose: this only has to find the edges of
    /// the text, not render anything legible, so measuring a whole book is one quick pass.
    static let sampleExtent: CGFloat = 200

    /// Measures every page. Call it on a `PDFDocument` of its own, off the main thread: PDFKit
    /// documents are not safe to share with the one on screen.
    func survey(of document: PDFDocument, progress: (Double) -> Void = { _ in }) -> PageVaultInkSurvey {
        let count = document.pageCount
        var boxes: [PageVaultInkBox?] = []
        boxes.reserveCapacity(count)
        for index in 0..<count {
            let box: PageVaultInkBox? = autoreleasepool { () -> PageVaultInkBox? in
                guard let page = document.page(at: index) else { return nil }
                return inkBox(of: page)
            }
            boxes.append(box)
            if index % 10 == 9 || index == count - 1 {
                progress(Double(index + 1) / Double(count))
            }
        }
        return PageVaultInkSurvey(boxes: boxes)
    }

    /// Renders the page's own content, unrotated, into a small grayscale bitmap and finds its ink.
    /// Drawing the raw page keeps the result in the same coordinate space as the crop box it sets,
    /// whatever rotation the page is displayed with.
    func inkBox(of page: PDFPage) -> PageVaultInkBox? {
        let box = page.bounds(for: .cropBox)
        guard box.width > 0, box.height > 0, let content = page.pageRef else { return nil }
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
            context.clip(to: box)
            context.drawPDFPage(content)
            return true
        }
        guard drawn else { return nil }
        return PageVaultInkScan.inkBox(pixels: pixels, width: width, height: height)
    }

    /// Sets each page's crop box from fractions of its published crop box. Apply once to a freshly
    /// opened document: the fractions are relative, so applying them twice would crop twice.
    static func apply(_ crops: [PageVaultInkBox?], to document: PDFDocument) {
        guard crops.count == document.pageCount else { return }
        for (index, crop) in crops.enumerated() {
            guard let crop, !crop.isEmpty, let page = document.page(at: index) else { continue }
            let box = page.bounds(for: .cropBox)
            guard box.width > 0, box.height > 0 else { continue }
            page.setBounds(CGRect(x: box.minX + box.width * crop.minX,
                                  y: box.minY + box.height * crop.minY,
                                  width: box.width * crop.width,
                                  height: box.height * crop.height),
                           for: .cropBox)
        }
    }
}
