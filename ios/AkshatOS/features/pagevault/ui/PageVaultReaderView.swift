import PDFKit
import SwiftUI

/// Commands the wrapped `PDFView` without reaching into undocumented subviews.
@MainActor final class PageVaultReaderController: ObservableObject {
    @Published var currentPage = 0
    /// True until the opening page has actually been applied. Page changes are ignored while it is
    /// set, because PDFKit reports page 0 during layout and that would otherwise overwrite the
    /// stored place with the beginning of the book.
    @Published private(set) var restoring = true
    /// Drives the highlighter button: there is nothing to highlight without a selection.
    @Published private(set) var hasSelection = false
    /// What the current selection covers, one entry per page it spans. Captured when the selection
    /// changes rather than on every redraw, so the highlighter menu can tell whether there is a
    /// mark to remove without reaching into the PDF view each time the toolbar is laid out.
    @Published private(set) var selectionCaptures: [PageVaultHighlightService.Capture] = []
    private weak var view: PDFView?
    private var jumper: ((Int, PageVaultFindMark?, Bool) -> Void)?
    /// The sentence being read aloud. Kept here because each page is its own view: the tint has to
    /// be put back on whichever page view becomes visible.
    private var spoken: PageVaultFindMark?
    /// Whether the visible page view carries the read-aloud tint, so clearing it never wipes a
    /// search result's tint that was not ours.
    private var tinted = false

    func attach(_ view: PDFView) {
        self.view = view
        tinted = false
        applySpoken()
    }

    /// Tints the sentence being read, or clears the tint with nil.
    func showSpoken(_ mark: PageVaultFindMark?) {
        spoken = mark
        applySpoken()
    }

    private func applySpoken() {
        guard let view, let document = view.document else { return }
        let shown = view.currentPage.map { document.index(for: $0) }
        if let spoken, spoken.page == shown,
           let found = PageVaultHighlightService.selection(for: spoken, in: document) {
            found.color = PageVaultHighlightService.reading
            view.highlightedSelections = [found]
            tinted = true
        } else if tinted {
            view.highlightedSelections = nil
            tinted = false
        }
    }

    func finishRestoring(at page: Int) {
        currentPage = page
        restoring = false
    }

    func report(page: Int) {
        guard !restoring else { return }
        currentPage = page
    }

    func report(selection: Bool) {
        hasSelection = selection
        selectionCaptures = selection ? captureSelection() : []
    }

    /// The current text selection, split per page, ready to be stored as highlights.
    func captureSelection() -> [PageVaultHighlightService.Capture] {
        guard let view, let document = view.document,
              let selection = view.currentSelection else { return [] }
        return PageVaultHighlightService.capture(selection, in: document)
    }

    func clearSelection() {
        view?.clearSelection()
        hasSelection = false
        selectionCaptures = []
    }

    /// Redraws the stored highlights on the open document, in memory only.
    func refreshHighlights(_ highlights: [PageVaultHighlight]) {
        guard let view, let document = view.document else { return }
        PageVaultHighlightService.apply(highlights, to: document)
        view.setNeedsDisplay()
    }

    /// Supplied by the pager, because each page is its own view: moving between them is not
    /// something the visible PDF view can do by itself.
    func attachJump(_ jump: @escaping (Int, PageVaultFindMark?, Bool) -> Void) { jumper = jump }

    /// Moves to a page. A `mark` tints the words that were searched for, so arriving from a result
    /// does not mean hunting down the page for them.
    func go(to index: Int, mark: PageVaultFindMark? = nil) {
        jumper?(index, mark, false)
        currentPage = index
    }

    /// Turns to a page with the page-curl, as reading aloud moves on.
    func turn(to index: Int) {
        guard index != currentPage else { return }
        currentPage = index
        jumper?(index, nil, true)
    }
}

struct PageVaultReaderView: View {
    let book: PageVaultBook
    let url: URL
    @ObservedObject var store: PageVaultStore
    /// Opens here instead of at the book's own place, for a reader reached from a Takeaways
    /// passage. Reading on from it still leaves the place alone: only bookmarking moves that.
    let openAt: Int?
    /// The app layer decides orientation; the reader only reports when it is on screen.
    let onReadingSessionChange: (Bool) -> Void

    @StateObject private var controller = PageVaultReaderController()
    @StateObject private var narrator: PageVaultNarrator
    /// Decided once, as the reader opens. Rebuilding the page view afterwards would lose the page
    /// being read, so a measurement that lands later is used the next time the book is opened.
    @State private var opened: Bool
    @State private var crops: [PageVaultInkBox?]?
    @State private var showHighlights = false
    @State private var showSearch = false
    @State private var showJump = false

    init(book: PageVaultBook, url: URL, store: PageVaultStore, openAt: Int? = nil,
         onReadingSessionChange: @escaping (Bool) -> Void = { _ in }) {
        self.book = book
        self.url = url
        _store = ObservedObject(wrappedValue: store)
        self.openAt = openAt
        self.onReadingSessionChange = onReadingSessionChange
        _narrator = StateObject(wrappedValue: PageVaultNarrator(url: url, title: book.title,
                                                                pageCount: book.pageCount))
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
                document
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 8) {
                            if narrator.state != .stopped { PageVaultReadAloudBar(narrator: narrator) }
                            pageIndicator
                        }
                    }
            } else {
                fitting
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { readAloudButton }
            ToolbarItem(placement: .topBarTrailing) { highlightButton }
            ToolbarItem(placement: .topBarTrailing) { readerMenu }
            ToolbarItem(placement: .topBarTrailing) { placeButton }
        }
        .sheet(isPresented: $showHighlights) {
            PageVaultHighlightsView(store: store, bookID: book.id) { page in
                showHighlights = false
                controller.go(to: page)
            }
        }
        .sheet(isPresented: $showSearch) {
            PageVaultSearchView(store: store, book: live) { hit in
                showSearch = false
                controller.go(to: hit.page, mark: hit.findMark)
            }
        }
        .sheet(isPresented: $showJump) {
            PageVaultPageJumpView(pageCount: book.pageCount,
                                  currentPage: controller.currentPage) { page in
                controller.go(to: page)
            }
        }
        .task { await openWhenFitted() }
        .onAppear {
            onReadingSessionChange(true)
            store.noteOpened(book)
        }
        .onDisappear {
            narrator.stop()
            onReadingSessionChange(false)
        }
        .onAppear {
            let reader = controller
            narrator.onPageTurn = { [weak reader] page in reader?.turn(to: page) }
        }
        .onChange(of: narrator.segment) { _, segment in controller.showSpoken(segment?.mark) }
        // Turning the page yourself moves reading to that page, playing or paused.
        .onChange(of: controller.currentPage) { _, page in narrator.follow(page: page) }
        .alert("Read aloud", isPresented: Binding(get: { narrator.notice != nil },
                                                  set: { if !$0 { narrator.clearNotice() } })) {
            Button("OK") { narrator.clearNotice() }
        } message: { Text(narrator.notice ?? "") }
    }

    /// Starts reading this page aloud, or stops reading. Pausing and skipping are on the bar that
    /// appears while it reads.
    private var readAloudButton: some View {
        Button {
            if narrator.state == .stopped {
                narrator.play(from: controller.currentPage)
            } else {
                narrator.stop()
            }
        } label: {
            Image(systemName: narrator.state == .stopped ? "headphones" : "headphones.circle.fill")
        }
        .disabled(controller.restoring)
        .accessibilityIdentifier("read-aloud")
        .accessibilityLabel(narrator.state == .stopped ? "Read aloud from this page" : "Stop reading aloud")
    }

    private var document: some View {
        PageVaultCurlDocumentView(url: url, openingPage: openAt ?? book.openingPage, crops: crops,
                                  highlights: live.highlights, theme: store.theme,
                                  zoom: store.readingZoom, controller: controller,
                                  onZoomChanged: { store.readingZoom = $0 })
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
                .tint(Palette.accent)
            Text("Fitting pages to your screen")
                .font(.headline)
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

    /// Select text with the usual gestures, then tap this. Keeping it in the toolbar avoids
    /// rebuilding PDFKit's own selection menu, which the reader does not own.
    ///
    /// It says which of the two things it is doing rather than inferring it. A single toggling
    /// button had to guess from the selection whether marking or unmarking was meant, and it
    /// guessed by comparing text, so a selection a word wider than an existing mark stacked a
    /// second mark instead of removing the first.
    @ViewBuilder private var highlightButton: some View {
        if controller.hasSelection {
            Menu {
                Button {
                    mark()
                } label: {
                    Label("Highlight", systemImage: "highlighter")
                }
                .accessibilityIdentifier("save-highlight")
                Button(role: .destructive) {
                    unmark()
                } label: {
                    Label("Remove highlight", systemImage: "eraser")
                }
                .disabled(!selectionCarriesHighlight)
                .accessibilityIdentifier("remove-highlight")
            } label: {
                Image(systemName: "highlighter")
            }
            .accessibilityIdentifier("highlighter")
            .accessibilityLabel("Highlight or remove the selected text")
        }
    }

    /// Whether "Remove highlight" has anything to remove, so it is never offered as a no-op.
    private var selectionCarriesHighlight: Bool {
        controller.selectionCaptures.contains {
            store.hasHighlights(page: $0.page, rects: $0.rects, in: live)
        }
    }

    /// Highlights, search and the page appearance share one menu, so the toolbar stays readable
    /// beside the highlighter and the bookmark.
    private var readerMenu: some View {
        Menu {
            Button {
                showHighlights = true
            } label: {
                Label("Highlights", systemImage: "quote.opening")
            }
            .accessibilityIdentifier("open-highlights")
            Button {
                showSearch = true
            } label: {
                Label("Search this book", systemImage: "magnifyingglass")
            }
            .accessibilityIdentifier("open-search")
            Divider()
            Picker("Page", selection: $store.theme) {
                ForEach(PageVaultTheme.allCases, id: \.self) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            .pickerStyle(.inline)
            .accessibilityIdentifier("reader-theme")
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityIdentifier("reader-menu")
        .accessibilityLabel("Reader options")
    }

    /// Marks the selection. Words that already carry a mark extend it rather than gaining a second
    /// one. A passage running across a page break is one mark per page, because each page carries
    /// its own rectangles.
    private func mark() {
        apply { capture in
            store.addHighlight(text: capture.text, page: capture.page, rects: capture.rects,
                               to: live)
        }
    }

    /// Clears every mark the selection covers, which is how one made by mistake is undone.
    private func unmark() {
        apply { capture in
            _ = store.clearHighlights(page: capture.page, rects: capture.rects, in: live)
        }
    }

    private func apply(_ change: (PageVaultHighlightService.Capture) -> Void) {
        let captures = controller.selectionCaptures
        guard !captures.isEmpty else { return }
        for capture in captures { change(capture) }
        controller.clearSelection()
        controller.refreshHighlights(store.book(id: book.id)?.highlights ?? [])
    }

    /// Tapping the indicator opens the page picker. Swiping is fine for the next page and useless
    /// for page 210 of 293, and the indicator is where you already look to know where you are.
    private var pageIndicator: some View {
        let placeNote = live.isPlace(page: controller.currentPage) ? " · your place" : ""
        return Button {
            showJump = true
        } label: {
            Text("\(controller.currentPage + 1) / \(book.pageCount)\(placeNote)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.black.opacity(0.4), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(controller.restoring || book.pageCount <= 1)
        .padding(.bottom, 14)
        .accessibilityIdentifier("reader-page-indicator")
        .accessibilityLabel("Page \(controller.currentPage + 1) of \(book.pageCount). Jump to a page.")
    }

}
