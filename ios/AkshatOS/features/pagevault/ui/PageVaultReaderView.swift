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
    var onReadingSessionChange: (Bool) -> Void = { _ in }

    @StateObject private var controller = PageVaultReaderController()
    @Environment(\.scenePhase) private var scenePhase

    /// The place can change while reading, so the live copy is read back from the store.
    private var live: PageVaultBook { store.book(id: book.id) ?? book }

    var body: some View {
        PageVaultDocumentView(url: url, openingPage: book.openingPage,
                              warmPaper: store.warmPaper, controller: controller)
            .overlay(alignment: .bottom) { pageIndicator }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { paperButton }
                ToolbarItem(placement: .topBarTrailing) { placeButton }
            }
            .onAppear { onReadingSessionChange(true) }
            .onDisappear {
                onReadingSessionChange(false)
                store.recordPageView(book, page: controller.currentPage)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { store.recordPageView(book, page: controller.currentPage) }
            }
            .task(id: controller.currentPage) { await recordAfterPause() }
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
            .foregroundStyle(.white.opacity(0.85))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.bottom, 14)
            .accessibilityIdentifier("reader-page-indicator")
    }

    /// Coalesces rapid page turns: `.task(id:)` cancels the pending write on the next turn, so
    /// moving quickly through a long book does not write once per page. This records reading
    /// progress for the streak only — it never moves your place.
    private func recordAfterPause() async {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled, !controller.restoring else { return }
        store.recordPageView(book, page: controller.currentPage)
    }
}

/// Wraps PDFKit's own view in single-page horizontal paging, so one page fills the screen and a
/// swipe moves exactly one page instead of scrolling two half pages into view.
private struct PageVaultDocumentView: UIViewRepresentable {
    let url: URL
    let openingPage: Int
    let warmPaper: Bool
    @ObservedObject var controller: PageVaultReaderController

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let view = PDFView()
        view.displayMode = .singlePage
        view.displayDirection = .horizontal
        view.autoScales = true
        view.translatesAutoresizingMaskIntoConstraints = false
        // One page per screen with real paging, rather than a continuous scroll of partial pages.
        view.usePageViewController(true, withViewOptions: nil)
        // PDFKit renders on demand; the document is never pre-rendered or fully buffered here.
        view.document = PDFDocument(url: url)

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
        context.coordinator.observe(view, controller: controller)
        context.coordinator.apply(warmPaper: warmPaper)
        // The opening page cannot be applied until PDFKit has laid the document out, so it is
        // retried after layout instead of being set once and silently ignored.
        context.coordinator.scheduleRestore(controller: controller)
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.apply(warmPaper: warmPaper)
        context.coordinator.scheduleRestore(controller: controller)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor final class Coordinator {
        weak var pdfView: PDFView?
        weak var tint: UIView?
        var pendingPage: Int?
        private var token: NSObjectProtocol?
        private var attempts = 0

        func apply(warmPaper: Bool) {
            pdfView?.backgroundColor = warmPaper
                ? UIColor(red: 0.16, green: 0.13, blue: 0.10, alpha: 1)
                : UIColor(Palette.background)
            tint?.backgroundColor = warmPaper
                ? UIColor(red: 0.99, green: 0.94, blue: 0.84, alpha: 1)
                : .white
            tint?.isHidden = !warmPaper
        }

        func observe(_ view: PDFView, controller: PageVaultReaderController) {
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
                controller.finishRestoring(at: 0)
                return
            }
            if let page = document.page(at: wanted) { view.go(to: page) }
            if let landed = view.currentPage, document.index(for: landed) == wanted {
                pendingPage = nil
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
        }
    }
}
