import PDFKit
import SwiftUI

/// Commands the wrapped `PDFView` without reaching into undocumented subviews.
@MainActor final class PageVaultReaderController: ObservableObject {
    @Published var currentPage = 0
    /// True until the opening page has actually been applied. Page changes are ignored while it is
    /// set, because PDFKit reports page 0 during layout and that would otherwise overwrite the
    /// stored place with the beginning of the book.
    @Published private(set) var restoring = true
    private weak var view: PDFView?

    func attach(_ view: PDFView) { self.view = view }

    func finishRestoring(at page: Int) {
        currentPage = page
        restoring = false
    }

    func report(page: Int) {
        guard !restoring else { return }
        currentPage = page
    }

    func go(to index: Int) {
        guard let view, let page = view.document?.page(at: index) else { return }
        view.go(to: page)
        currentPage = index
    }
}

struct PageVaultReaderView: View {
    let book: PageVaultBook
    let url: URL
    @ObservedObject var store: PageVaultStore
    /// The app layer decides orientation; the reader only reports when it is on screen.
    let onReadingSessionChange: (Bool) -> Void

    @StateObject private var controller = PageVaultReaderController()
    /// Decided once, as the reader opens. Rebuilding the page view afterwards would lose the page
    /// being read, so a measurement that lands later is used the next time the book is opened.
    @State private var opened: Bool
    @State private var crops: [PageVaultInkBox?]?

    init(book: PageVaultBook, url: URL, store: PageVaultStore,
         onReadingSessionChange: @escaping (Bool) -> Void = { _ in }) {
        self.book = book
        self.url = url
        _store = ObservedObject(wrappedValue: store)
        self.onReadingSessionChange = onReadingSessionChange
        // An already-measured book opens fitted on the first frame, with no fitting screen at all.
        let fitted = store.pageCrops(for: book)
        _crops = State(initialValue: fitted)
        _opened = State(initialValue: fitted != nil)
    }

    /// The place can change while reading, so the live copy is read back from the store.
    private var live: PageVaultBook { store.book(id: book.id) ?? book }

    var body: some View {
        Group {
            if opened {
                PageVaultDocumentView(url: url, openingPage: book.openingPage, crops: crops,
                                      warmPaper: store.warmPaper, zoom: store.readingZoom,
                                      controller: controller,
                                      onZoomChanged: { store.readingZoom = $0 })
                    .overlay(alignment: .bottom) { pageIndicator }
            } else {
                fitting
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { paperButton }
            ToolbarItem(placement: .topBarTrailing) { placeButton }
        }
        .task { await openWhenFitted() }
        .onAppear {
            onReadingSessionChange(true)
            store.noteOpened(book)
        }
        .onDisappear { onReadingSessionChange(false) }
    }

    /// Measures the book's pages first when that has not happened yet — joining a measurement
    /// already under way — then opens. A book that cannot be measured opens as published.
    private func openWhenFitted() async {
        if store.pageCrops(for: book) == nil && !store.layoutUnavailable(for: book) {
            await store.ensureLayout(for: book)
        }
        guard !opened else { return }
        crops = store.pageCrops(for: book)
        opened = true
    }

    private var fitting: some View {
        VStack(spacing: 18) {
            ProgressView(value: store.fittingProgress(for: book))
                .tint(Palette.lime)
            Text("Fitting pages to your screen")
                .font(.system(.headline, design: .rounded))
            Text("PageVault finds where the text sits on every page, once per book, so each page opens cropped to its text.")
                .font(.caption).foregroundStyle(Palette.muted)
                .multilineTextAlignment(.center)
            Button("Read without fitting") { opened = true }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("read-without-fitting")
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.ignoresSafeArea())
        .accessibilityIdentifier("pagevault-fitting")
    }

    /// Bookmarking is what moves your place, so this is the only control that changes where the
    /// book reopens. Browsing away and closing the app leaves the place untouched.
    private var placeButton: some View {
        let marked = live.isPlace(page: controller.currentPage)
        return Button {
            if marked {
                store.clearPlace(live)
            } else {
                store.setPlace(live, page: controller.currentPage)
            }
        } label: {
            Image(systemName: marked ? "bookmark.fill" : "bookmark")
        }
        .disabled(controller.restoring)
        .accessibilityIdentifier("toggle-bookmark")
        .accessibilityLabel(marked ? "Remove your place" : "Save your place on this page")
    }

    private var paperButton: some View {
        Button {
            store.warmPaper.toggle()
        } label: {
            Image(systemName: store.warmPaper ? "sun.max.fill" : "sun.max")
        }
        .accessibilityIdentifier("toggle-warm-paper")
        .accessibilityLabel(store.warmPaper ? "Use plain white pages" : "Use warm paper")
    }

    private var pageIndicator: some View {
        let placeNote = live.isPlace(page: controller.currentPage) ? " · your place" : ""
        return Text("\(controller.currentPage + 1) / \(book.pageCount)\(placeNote)")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.4), in: Capsule())
            .padding(.bottom, 14)
            .accessibilityIdentifier("reader-page-indicator")
    }

}

/// Wraps PDFKit's own view in single-page horizontal paging, so one page fills the screen and a
/// swipe moves exactly one page instead of scrolling two half pages into view.
private struct PageVaultDocumentView: UIViewRepresentable {
    let url: URL
    let openingPage: Int
    /// Per-page crop boxes from the book's measurement, or nil to show pages as published.
    let crops: [PageVaultInkBox?]?
    let warmPaper: Bool
    let zoom: Double
    @ObservedObject var controller: PageVaultReaderController
    let onZoomChanged: (Double) -> Void

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let view = PDFView()
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.autoScales = true
        view.pageShadowsEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        // One page per screen with real paging, rather than a continuous scroll of partial pages.
        view.usePageViewController(true, withViewOptions: nil)
        // PDFKit renders on demand; the document is never pre-rendered or fully buffered here.
        let document = PDFDocument(url: url)
        if let document {
            // Crop every page to its measured text before first layout, so the text block rather
            // than the paper fills the screen. Without a measurement the pages open as published.
            if let crops { PageVaultPageLayout.apply(crops, to: document) }
            view.displayBox = .cropBox
        }
        view.document = document

        let tint = UIView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        tint.isUserInteractionEnabled = false
        // Multiply keeps black text black while warming the white of the page, which a plain
        // translucent overlay cannot do without washing the text out.
        tint.layer.compositingFilter = "multiplyBlendMode"

        container.addSubview(view)
        container.addSubview(tint)
        for child in [view, tint] {
            NSLayoutConstraint.activate([
                child.topAnchor.constraint(equalTo: container.topAnchor),
                child.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                child.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                child.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
        }

        controller.attach(view)
        context.coordinator.pdfView = view
        context.coordinator.tint = tint
        context.coordinator.pendingPage = openingPage
        context.coordinator.onZoomChanged = onZoomChanged
        context.coordinator.observe(view, controller: controller)
        context.coordinator.apply(warmPaper: warmPaper)
        context.coordinator.apply(zoom: zoom)
        // The opening page cannot be applied until PDFKit has laid the document out, so it is
        // retried after layout instead of being set once and silently ignored.
        context.coordinator.scheduleRestore(controller: controller)
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onZoomChanged = onZoomChanged
        context.coordinator.apply(warmPaper: warmPaper)
        context.coordinator.apply(zoom: zoom)
        context.coordinator.scheduleRestore(controller: controller)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor final class Coordinator {
        weak var pdfView: PDFView?
        weak var tint: UIView?
        var pendingPage: Int?
        var onZoomChanged: ((Double) -> Void)?
        private var token: NSObjectProtocol?
        private var scaleToken: NSObjectProtocol?
        private var attempts = 0
        private var requestedZoom = PageVaultStore.minimumZoom
        private var applyingZoom = false

        /// The surround is kept the same white as the page, so a page narrower than the screen
        /// blends into it instead of sitting inside dark letterbox bands. The warm overlay then
        /// tints page and surround together, giving one continuous sheet of paper.
        func apply(warmPaper: Bool) {
            pdfView?.backgroundColor = .white
            tint?.backgroundColor = UIColor(red: 0.99, green: 0.94, blue: 0.84, alpha: 1)
            tint?.isHidden = !warmPaper
        }

        /// Anchors zoom to the fit scale: the floor is the whole cropped page, so the text can
        /// never be dialled smaller than "everything visible", and the ceiling stops a stray pinch
        /// leaving the reader somewhere unusable.
        func apply(zoom: Double) {
            requestedZoom = PageVaultStore.clampZoom(zoom)
            guard let view = pdfView, view.document != nil else { return }
            let fit = view.scaleFactorForSizeToFit
            guard fit > 0 else { return }
            view.minScaleFactor = fit
            view.maxScaleFactor = fit * CGFloat(PageVaultStore.maximumZoom)
            let target = fit * CGFloat(requestedZoom)
            guard abs(view.scaleFactor - target) > 0.001 else { return }
            applyingZoom = true
            view.scaleFactor = target
            applyingZoom = false
        }

        func observeScale(_ view: PDFView) {
            guard scaleToken == nil else { return }
            scaleToken = NotificationCenter.default.addObserver(
                forName: .PDFViewScaleChanged, object: view, queue: .main
            ) { [weak self] note in
                guard let self, !self.applyingZoom,
                      let view = note.object as? PDFView, view.document != nil else { return }
                let fit = view.scaleFactorForSizeToFit
                guard fit > 0 else { return }
                let ratio = Double(view.scaleFactor / fit)
                Task { @MainActor in self.report(zoom: ratio) }
            }
        }

        private func report(zoom: Double) {
            let clamped = PageVaultStore.clampZoom(zoom)
            guard abs(clamped - requestedZoom) > 0.01 else { return }
            requestedZoom = clamped
            onZoomChanged?(clamped)
        }

        func observe(_ view: PDFView, controller: PageVaultReaderController) {
            observeScale(view)
            guard token == nil else { return }
            token = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged, object: view, queue: .main
            ) { note in
                guard let view = note.object as? PDFView, let page = view.currentPage,
                      let document = view.document else { return }
                let index = document.index(for: page)
                guard index != NSNotFound else { return }
                Task { @MainActor in controller.report(page: index) }
            }
        }

        /// Retries the opening page until PDFKit reports it, then hands control to the reader.
        func scheduleRestore(controller: PageVaultReaderController) {
            guard let target = pendingPage else { return }
            guard let view = pdfView, let document = view.document, document.pageCount > 0 else {
                retry(controller: controller)
                return
            }
            let wanted = min(max(target, 0), document.pageCount - 1)
            if wanted == 0 {
                pendingPage = nil
                apply(zoom: requestedZoom)
                controller.finishRestoring(at: 0)
                return
            }
            if let page = document.page(at: wanted) { view.go(to: page) }
            if let landed = view.currentPage, document.index(for: landed) == wanted {
                pendingPage = nil
                apply(zoom: requestedZoom)
                controller.finishRestoring(at: wanted)
            } else {
                retry(controller: controller)
            }
        }

        private func retry(controller: PageVaultReaderController) {
            attempts += 1
            // Give up rather than spin forever; a failed restore means reading from page one,
            // which is recoverable, whereas an endless retry loop is not.
            guard attempts < 40 else {
                pendingPage = nil
                controller.finishRestoring(at: controller.currentPage)
                return
            }
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(50))
                self?.scheduleRestore(controller: controller)
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
            if let scaleToken { NotificationCenter.default.removeObserver(scaleToken) }
        }
    }
}
