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
    @State private var showNavigator = false
    @State private var navigatorTab = NavigatorTab.contents

    private enum NavigatorTab: String, CaseIterable {
        case contents, bookmarks
        var label: String { rawValue.capitalized }
    }

    /// Bookmarks change while reading, so the live copy is read back from the store.
    private var live: PageVaultBook { store.book(id: book.id) ?? book }

    var body: some View {
        PageVaultDocumentView(url: url, initialPage: book.resolvedPage(), controller: controller)
            .overlay(alignment: .bottom) { pageIndicator }
            .navigationTitle(book.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { bookmarkButton }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNavigator = true } label: {
                        Image(systemName: "list.bullet.indent")
                    }
                    .accessibilityIdentifier("open-table-of-contents")
                    .accessibilityLabel("Contents and bookmarks")
                }
            }
            .sheet(isPresented: $showNavigator) { navigator }
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

    private var bookmarkButton: some View {
        let marked = live.hasBookmark(page: controller.currentPage)
        return Button {
            store.toggleBookmark(live, page: controller.currentPage)
        } label: {
            Image(systemName: marked ? "bookmark.fill" : "bookmark")
        }
        .accessibilityIdentifier("toggle-bookmark")
        .accessibilityLabel(marked ? "Remove bookmark" : "Bookmark this page")
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

    private var navigator: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("View", selection: $navigatorTab) {
                    ForEach(NavigatorTab.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal).padding(.bottom, 8)

                switch navigatorTab {
                case .contents: contentsList
                case .bookmarks: bookmarksList
                }
            }
            .navigationTitle("Navigate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showNavigator = false }
                }
            }
        }
    }

    @ViewBuilder private var contentsList: some View {
        if !outlineLoaded {
            ProgressView().frame(maxHeight: .infinity)
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
                    showNavigator = false
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

    @ViewBuilder private var bookmarksList: some View {
        let bookmarks = live.bookmarks
        if bookmarks.isEmpty {
            ContentUnavailableView("No bookmarks", systemImage: "bookmark",
                                   description: Text("Tap the bookmark button to save your place."))
                .accessibilityIdentifier("reader-no-bookmarks")
        } else {
            List {
                ForEach(bookmarks) { bookmark in
                    Button {
                        controller.go(to: bookmark.page)
                        showNavigator = false
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Page \(bookmark.page + 1)").font(.subheadline.monospacedDigit())
                            if let note = bookmark.note {
                                Text(note).font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { store.removeBookmark(live, id: bookmarks[index].id) }
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
