import PDFKit
import SwiftUI
import UIKit

// The page-curl reader. PDFKit's own paging offers no curl, so this hosts one `PDFView` per page
// inside the system curl transition instead.
//
// The device pass confirmed the curl and drag-to-select coexist, so this is now the only reader and
// PDFKit's plain paging was removed rather than kept as a dormant second path. Because each page is
// its own view, this file owns two things the single-view reader used to: jumping to a page for a
// search result or a highlight, and remembering a pinch across pages and books.

/// One page of the book, with the theme overlay the rest of the reader uses.
final class PageVaultCurlPage: UIViewController {
    let index: Int
    private let document: PDFDocument
    private let zoom: Double
    private var theme: PageVaultTheme
    private let onVisible: (Int, PDFView) -> Void
    private let onSelection: (Bool) -> Void
    private let onZoom: (Double) -> Void
    private let pdfView = PDFView()
    private let tint = UIView()
    private var selectionToken: NSObjectProtocol?
    private var scaleToken: NSObjectProtocol?
    private var zoomApplied = false
    private var applyingZoom = false

    init(document: PDFDocument, index: Int, theme: PageVaultTheme, zoom: Double,
         onVisible: @escaping (Int, PDFView) -> Void, onSelection: @escaping (Bool) -> Void,
         onZoom: @escaping (Double) -> Void) {
        self.document = document
        self.index = index
        self.theme = theme
        self.zoom = zoom
        self.onVisible = onVisible
        self.onSelection = onSelection
        self.onZoom = onZoom
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("PageVaultCurlPage is created in code only") }

    override func viewDidLoad() {
        super.viewDidLoad()
        pdfView.displayMode = .singlePage
        pdfView.autoScales = true
        pdfView.pageShadowsEnabled = false
        pdfView.backgroundColor = .white
        pdfView.displayBox = .cropBox
        pdfView.document = document
        if let page = document.page(at: index) { pdfView.go(to: page) }

        tint.isUserInteractionEnabled = false
        for child in [pdfView, tint] {
            child.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(child)
            NSLayoutConstraint.activate([
                child.topAnchor.constraint(equalTo: view.topAnchor),
                child.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                child.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            ])
        }
        apply(theme: theme)

        selectionToken = NotificationCenter.default.addObserver(
            forName: .PDFViewSelectionChanged, object: pdfView, queue: .main
        ) { [weak self] _ in
            let selected = self?.pdfView.currentSelection?.string?
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            self?.onSelection(selected)
        }

        // Pinching on one page is remembered for every other page and every other book, which is
        // what the single-view reader did before the curl replaced it.
        scaleToken = NotificationCenter.default.addObserver(
            forName: .PDFViewScaleChanged, object: pdfView, queue: .main
        ) { [weak self] _ in
            guard let self, self.zoomApplied, !self.applyingZoom else { return }
            let fit = self.pdfView.scaleFactorForSizeToFit
            guard fit > 0 else { return }
            self.onZoom(Double(self.pdfView.scaleFactor / fit))
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The remembered zoom needs a laid-out view to measure the fit against.
        guard !zoomApplied else { return }
        let fit = pdfView.scaleFactorForSizeToFit
        guard fit > 0 else { return }
        zoomApplied = true
        pdfView.minScaleFactor = fit
        pdfView.maxScaleFactor = fit * CGFloat(PageVaultStore.maximumZoom)
        applyingZoom = true
        pdfView.scaleFactor = fit * CGFloat(PageVaultStore.clampZoom(zoom))
        applyingZoom = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The curl has settled here. There is no pager delegate to say so — the app layer owns the
        // only delegate in this project — so the page that became visible reports itself.
        onVisible(index, pdfView)
    }

    func apply(theme: PageVaultTheme) {
        self.theme = theme
        switch theme {
        case .paper:
            tint.isHidden = true
        case .sepia:
            tint.layer.compositingFilter = "multiplyBlendMode"
            tint.backgroundColor = UIColor(red: 0.93, green: 0.86, blue: 0.72, alpha: 1)
            tint.isHidden = false
        case .night:
            tint.layer.compositingFilter = "differenceBlendMode"
            tint.backgroundColor = .white
            tint.isHidden = false
        }
    }

    deinit {
        if let selectionToken { NotificationCenter.default.removeObserver(selectionToken) }
        if let scaleToken { NotificationCenter.default.removeObserver(scaleToken) }
    }
}

struct PageVaultCurlDocumentView: UIViewControllerRepresentable {
    let url: URL
    let openingPage: Int
    let crops: [PageVaultInkBox?]?
    let highlights: [PageVaultHighlight]
    let theme: PageVaultTheme
    let zoom: Double
    @ObservedObject var controller: PageVaultReaderController
    let onZoomChanged: (Double) -> Void

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(
            transitionStyle: .pageCurl, navigationOrientation: .horizontal,
            options: [.spineLocation: UIPageViewController.SpineLocation.min.rawValue])
        let document = PDFDocument(url: url)
        if let document {
            if let crops { PageVaultPageLayout.apply(crops, to: document) }
            PageVaultHighlightService.apply(highlights, to: document)
        }
        context.coordinator.configure(document: document, theme: theme, zoom: zoom,
                                      controller: controller, onZoom: onZoomChanged)
        context.coordinator.attach(pager: pager)
        // Each page is its own view, so a search result or a highlight is only reachable by the
        // pager swapping that page in.
        controller.attachJump { [weak coordinator = context.coordinator] index in
            coordinator?.jump(to: index)
        }
        // Only the data source is set: supplying pages is all this needs, and a delegate would
        // break the project's rule that the app layer owns them.
        pager.dataSource = context.coordinator

        let start = min(max(openingPage, 0), max(0, (document?.pageCount ?? 1) - 1))
        if let first = context.coordinator.page(at: start) {
            pager.setViewControllers([first], direction: .forward, animated: false)
        }
        controller.finishRestoring(at: start)
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.apply(theme: theme)
        context.coordinator.apply(highlights: highlights)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// UIKit calls a data source on the main thread, so this is main-thread state without being
    /// formally isolated: a `@MainActor` type cannot satisfy the nonisolated data-source protocol.
    final class Coordinator: NSObject, UIPageViewControllerDataSource {
        private var document: PDFDocument?
        private var theme: PageVaultTheme = .sepia
        private var zoom: Double = 1
        private weak var controller: PageVaultReaderController?
        private weak var pager: UIPageViewController?
        private var onZoom: (Double) -> Void = { _ in }
        /// The pages currently in play. The pager keeps only a few alive; this bounded list is what
        /// lets a theme change reach the ones on screen.
        private var live: [PageVaultCurlPage] = []

        func configure(document: PDFDocument?, theme: PageVaultTheme, zoom: Double,
                       controller: PageVaultReaderController, onZoom: @escaping (Double) -> Void) {
            self.document = document
            self.theme = theme
            self.zoom = zoom
            self.controller = controller
            self.onZoom = onZoom
        }

        func attach(pager: UIPageViewController) { self.pager = pager }

        /// Moves to a page without animating: this is a jump from a search result or the highlights
        /// list, not a page turn.
        func jump(to index: Int) {
            guard let pager, let target = page(at: index) else { return }
            pager.setViewControllers([target], direction: .forward, animated: false)
        }

        func page(at index: Int) -> PageVaultCurlPage? {
            guard let document, index >= 0, index < document.pageCount else { return nil }
            let page = PageVaultCurlPage(
                document: document, index: index, theme: theme, zoom: zoom,
                onVisible: { [weak self] shown, view in
                    guard let controller = self?.controller else { return }
                    Task { @MainActor in
                        controller.attach(view)
                        controller.report(page: shown)
                    }
                },
                onSelection: { [weak self] selected in
                    guard let controller = self?.controller else { return }
                    Task { @MainActor in controller.report(selection: selected) }
                },
                onZoom: { [weak self] ratio in
                    guard let report = self?.onZoom else { return }
                    Task { @MainActor in report(ratio) }
                })
            live.append(page)
            if live.count > 6 { live.removeFirst(live.count - 6) }
            return page
        }

        func apply(theme: PageVaultTheme) {
            self.theme = theme
            for page in live { page.apply(theme: theme) }
        }

        func apply(highlights: [PageVaultHighlight]) {
            guard let document else { return }
            PageVaultHighlightService.apply(highlights, to: document)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let current = viewController as? PageVaultCurlPage else { return nil }
            return page(at: current.index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let current = viewController as? PageVaultCurlPage else { return nil }
            return page(at: current.index + 1)
        }
    }
}
