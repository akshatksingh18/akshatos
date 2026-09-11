import SwiftUI

/// Every passage saved from one book, in reading order. Opened from the reader it can jump to a
/// page; opened from book details it is a list to read. The whole set exports as its own PDF.
struct PageVaultHighlightsView: View {
    @ObservedObject var store: PageVaultStore
    let bookID: UUID
    /// Supplied by the reader, which is the only place that can move to a page.
    var onJump: ((Int) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var staged: URL?
    @State private var showMover = false
    @State private var notice: String?

    private var book: PageVaultBook? { store.book(id: bookID) }

    var body: some View {
        NavigationStack {
            Group {
                if let book, !book.highlights.isEmpty {
                    List {
                        ForEach(book.highlightsInReadingOrder) { highlight in
                            row(highlight, in: book)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "No highlights yet", systemImage: "highlighter",
                        description: Text("Select a line while reading, then tap the highlighter."))
                }
            }
            .navigationTitle("Highlights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Export") { exportPDF() }
                        .disabled(book?.highlights.isEmpty ?? true)
                        .accessibilityIdentifier("export-highlights")
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .fileMover(isPresented: $showMover, file: staged) { result in
            if case .failure(let error) = result, (error as? CocoaError)?.code != .userCancelled {
                notice = "The highlights were not saved: \(error.localizedDescription)"
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

    private func row(_ highlight: PageVaultHighlight, in book: PageVaultBook) -> some View {
        Button {
            onJump?(highlight.page)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text("PAGE \(highlight.page + 1)")
                    .font(.caption2.weight(.bold)).tracking(1.5)
                    .foregroundStyle(Palette.muted)
                Text(highlight.text)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onJump == nil)
        .accessibilityIdentifier("highlight-\(highlight.id.uuidString)")
        .swipeActions {
            Button("Delete", role: .destructive) {
                store.removeHighlight(highlight.id, from: book)
            }
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
