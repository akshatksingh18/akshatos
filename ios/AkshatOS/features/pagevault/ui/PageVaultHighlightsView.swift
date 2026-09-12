import SwiftUI

/// The passages kept from one book, in reading order, each as its own block so a line reads without
/// tapping into anything. Reached from the reader, where it can move the open book to a page, or
/// from Takeaways, where it opens the book instead. The whole set exports as its own PDF.
struct PageVaultHighlightList: View {
    @ObservedObject var store: PageVaultStore
    let bookID: UUID
    /// Supplied by the reader, the only place that can move a book that is already open.
    var onJump: ((Int) -> Void)?
    /// Set from Takeaways, where no book is open, so a passage opens its own book at that page.
    var opensBook = false
    /// Only meaningful alongside `opensBook`: opening a reader from here is a reading session too,
    /// and the app layer decides orientation from it.
    var onReadingSessionChange: (Bool) -> Void = { _ in }

    @State private var staged: URL?
    @State private var showMover = false
    @State private var notice: String?
    /// Deleting asks first. "Go to page" and the bin sit next to each other, and a passage removed
    /// by a mistap was gone with nothing to undo it.
    @State private var pendingDeletion: PageVaultHighlight?

    private var book: PageVaultBook? { store.book(id: bookID) }

    var body: some View {
        Group {
            if let book, !book.highlights.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(book.highlightsInReadingOrder) { highlight in
                            block(highlight, in: book)
                        }
                    }
                    .padding(20)
                }
            } else {
                ContentUnavailableView(
                    "Nothing kept from this book", systemImage: "quote.opening",
                    description: Text("Select a line while reading, then tap the highlighter."))
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle(book?.title ?? "Takeaways")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Export") { exportPDF() }
                    .disabled(book?.highlights.isEmpty ?? true)
                    .accessibilityIdentifier("export-highlights")
            }
        }
        .confirmationDialog("Remove this passage?",
                            isPresented: Binding(get: { pendingDeletion != nil },
                                                 set: { if !$0 { pendingDeletion = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingDeletion) { highlight in
            Button("Remove passage", role: .destructive) {
                if let book { store.removeHighlight(highlight.id, from: book) }
                pendingDeletion = nil
            }
            .accessibilityIdentifier("confirm-remove-highlight")
            Button("Keep it", role: .cancel) { pendingDeletion = nil }
        } message: { highlight in
            Text("The mark on page \(highlight.page + 1) goes with it. The book itself is untouched.")
        }
        .fileMover(isPresented: $showMover, file: staged) { result in
            if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                notice = "The takeaways were not saved: \(error.localizedDescription)"
            }
            store.finishExport()
            staged = nil
        }
        .alert("PageVault", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("OK") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    /// One passage, one block: the whole line is visible, with its page and the controls under it.
    private func block(_ highlight: PageVaultHighlight, in book: PageVaultBook) -> some View {
        Surface {
            Text(highlight.text)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 16) {
                Text("Page \(highlight.page + 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                Spacer()
                jump(to: highlight, in: book)
                Button(role: .destructive) {
                    pendingDeletion = highlight
                } label: {
                    Image(systemName: "trash")
                }
                .font(.caption)
                .accessibilityLabel("Remove this passage")
                .accessibilityIdentifier("remove-\(highlight.id.uuidString)")
            }
        }
        .accessibilityIdentifier("highlight-\(highlight.id.uuidString)")
    }

    /// The same control either way, doing the only thing each place can: the reader moves the book
    /// it already has open, while Takeaways has to open it first.
    @ViewBuilder
    private func jump(to highlight: PageVaultHighlight, in book: PageVaultBook) -> some View {
        if let onJump {
            Button("Go to page") { onJump(highlight.page) }
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("jump-\(highlight.id.uuidString)")
        } else if opensBook, let url = store.documentURL(for: book) {
            NavigationLink {
                PageVaultReaderView(book: book, url: url, store: store, openAt: highlight.page,
                                    onReadingSessionChange: onReadingSessionChange)
            } label: {
                Text("Go to page")
                    .font(.caption.weight(.semibold))
            }
            .accessibilityIdentifier("jump-\(highlight.id.uuidString)")
        }
    }

    private func exportPDF() {
        guard let book else { return }
        Task {
            do {
                staged = try await store.prepareHighlightsExport(for: book)
                showMover = true
            } catch {
                notice = error.localizedDescription
            }
        }
    }
}

/// The reader's sheet around the same list, with its own navigation and a way out.
struct PageVaultHighlightsView: View {
    @ObservedObject var store: PageVaultStore
    let bookID: UUID
    var onJump: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PageVaultHighlightList(store: store, bookID: bookID, onJump: onJump)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                }
        }
    }
}
