import PDFKit
import SwiftUI

/// Commands the wrapped `PDFView` without reaching into undocumented subviews.
@MainActor final class PageVaultReaderController: ObservableObject {
    @Published var currentPage = 0
    private weak var view: PDFView?

    func attach(_ view: PDFView) { self.view = view }

    func prime(page: Int) { currentPage = page }

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
    @State private var outline: [PageVaultOutlineNode] = []
    @State private var outlineLoaded = false
    @State private var showOutline = false

    var body: some View {
        PageVaultDocumentView(url: url, initialPage: book.resolvedPage(), controller: controller)
            .overlay(alignment: .bottom) { pageIndicator }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showOutline = true } label: {
                        Image(systemName: "list.bullet.indent")
                    }
                    .accessibilityIdentifier("open-table-of-contents")
                    .accessibilityLabel("Table of contents")
                }
            }
            .sheet(isPresented: $showOutline) { outlineSheet }
            .task { await loadOutline() }
            .task(id: controller.currentPage) { await persistAfterPause() }
            .onAppear {
                controller.prime(page: book.resolvedPage())
                onReadingSessionChange(true)
            }
            .onDisappear {
                onReadingSessionChange(false)
                store.remember(book, page: controller.currentPage)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { store.remember(book, page: controller.currentPage) }
            }
    }

    private var pageIndicator: some View {
        Text("\(controller.currentPage + 1) / \(book.pageCount)")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(.bottom, 14)
            .accessibilityIdentifier("reader-page-indicator")
    }

    private var outlineSheet: some View {
        NavigationStack {
            Group {
                if !outlineLoaded {
                    ProgressView()
                } else if outline.isEmpty {
                    // A PDF without an embedded outline gets an honest state; none is invented.
                    ContentUnavailableView("No table of contents",
                                           systemImage: "list.bullet.indent",
                                           description: Text("This PDF has no embedded outline."))
                        .accessibilityIdentifier("reader-no-outline")
                } else {
                    List(PageVaultOutlineNode.rows(outline)) { row in
                        Button {
                            if let page = row.page { controller.go(to: page) }
                            showOutline = false
                        } label: {
                            HStack {
                                Text(row.title).lineLimit(2)
                                Spacer()
                                if let page = row.page {
                                    Text("\(page + 1)").font(.caption.monospacedDigit())
                                        .foregroundStyle(Palette.muted)
                                }
                            }
                            .padding(.leading, CGFloat(row.level) * 16)
                        }
                        .disabled(row.page == nil)
                    }
                }
            }
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showOutline = false }
                }
            }
        }
    }

    private func loadOutline() async {
        guard !outlineLoaded else { return }
        outline = await store.outline(for: book)
        outlineLoaded = true
    }

    /// Coalesces rapid page changes: `.task(id:)` cancels the pending save on the next turn, so
    /// scrolling quickly through a long book does not write once per page.
    private func persistAfterPause() async {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        store.remember(book, page: controller.currentPage)
    }
}

/// Wraps PDFKit's own view. Page changes arrive through `PDFViewPageChanged` rather than a
/// delegate, keeping process-wide delegate ownership with the app coordinator.
private struct PageVaultDocumentView: UIViewRepresentable {
    let url: URL
    let initialPage: Int
    @ObservedObject var controller: PageVaultReaderController

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.autoScales = true
        view.backgroundColor = UIColor(Palette.background)
        // PDFKit renders on demand; the document is never pre-rendered or fully buffered here.
        view.document = PDFDocument(url: url)
        if let page = view.document?.page(at: initialPage) { view.go(to: page) }
        controller.attach(view)
        context.coordinator.observe(view, controller: controller)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        private var token: NSObjectProtocol?

        func observe(_ view: PDFView, controller: PageVaultReaderController) {
            token = NotificationCenter.default.addObserver(
                forName: .PDFViewPageChanged, object: view, queue: .main
            ) { note in
                guard let view = note.object as? PDFView, let page = view.currentPage,
                      let document = view.document else { return }
                let index = document.index(for: page)
                guard index != NSNotFound else { return }
                Task { @MainActor in controller.currentPage = index }
            }
        }

        deinit {
            if let token { NotificationCenter.default.removeObserver(token) }
        }
    }
}
