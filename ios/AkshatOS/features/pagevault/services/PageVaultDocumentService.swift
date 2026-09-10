import Foundation
import PDFKit

/// The only place import-time PDFKit inspection happens, keeping PDFKit out of the domain layer.
/// Inspection opens the document lazily: it reads page count, metadata, and outline without
/// rendering pages or loading the file into memory.
protocol PageVaultDocumentInspecting: Sendable {
    func inspect(_ url: URL) throws -> PageVaultDocumentService.Inspection
    func outline(of url: URL) -> [PageVaultOutlineNode]
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
