import Foundation
import PDFKit
import UIKit

/// The only place import-time PDFKit inspection happens, keeping PDFKit out of the domain layer.
/// Inspection opens the document lazily: it reads page count, metadata, and outline without
/// rendering pages or loading the file into memory.
protocol PageVaultDocumentInspecting: Sendable {
    func inspect(_ url: URL) throws -> PageVaultDocumentService.Inspection
    func outline(of url: URL) -> [PageVaultOutlineNode]
    func coverPNG(of url: URL, maxPixel: CGFloat) -> Data?
}

struct PageVaultDocumentService: PageVaultDocumentInspecting {
    struct Inspection: Equatable {
        var pageCount: Int
        var metadataTitle: String?
    }

    func inspect(_ url: URL) throws -> Inspection {
        guard let document = PDFDocument(url: url) else { throw PageVaultImportFailure.unreadable }
        guard !document.isLocked else { throw PageVaultImportFailure.passwordProtected }
        guard document.pageCount > 0 else { throw PageVaultImportFailure.noPages }
        let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        return Inspection(pageCount: document.pageCount, metadataTitle: title)
    }

    /// Renders page one only. Covers are regenerable, so a failure here is never fatal.
    func coverPNG(of url: URL, maxPixel: CGFloat = 600) -> Data? {
        guard let document = PDFDocument(url: url), !document.isLocked,
              let page = document.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .cropBox)
        let longest = max(bounds.width, bounds.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxPixel / longest)
        let size = CGSize(width: max(1, bounds.width * scale), height: max(1, bounds.height * scale))
        return page.thumbnail(of: size, for: .cropBox).pngData()
    }

    func outline(of url: URL) -> [PageVaultOutlineNode] {
        guard let document = PDFDocument(url: url), !document.isLocked,
              let root = document.outlineRoot else { return [] }
        return children(of: root, in: document, path: "")
    }

    private func children(of outline: PDFOutline, in document: PDFDocument,
                          path: String) -> [PageVaultOutlineNode] {
        (0..<outline.numberOfChildren).compactMap { index in
            guard let child = outline.child(at: index) else { return nil }
            let identifier = path.isEmpty ? "\(index)" : "\(path).\(index)"
            let label = (child.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return PageVaultOutlineNode(
                id: identifier,
                title: label.isEmpty ? "Untitled section" : label,
                page: pageIndex(of: child, in: document),
                children: children(of: child, in: document, path: identifier))
        }
    }

    private func pageIndex(of outline: PDFOutline, in document: PDFDocument) -> Int? {
        guard let page = outline.destination?.page else { return nil }
        let index = document.index(for: page)
        return index == NSNotFound ? nil : index
    }
}
