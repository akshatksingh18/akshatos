import SwiftUI
import UniformTypeIdentifiers

/// Minimal library for the phase-2 spike: import, open, resume, remove. Cover thumbnails,
/// reading status, streaks, bookmarks, and themes are deliberately not here yet.
struct PageVaultLibraryView: View {
    @ObservedObject var store: PageVaultStore
    var onReadingSessionChange: (Bool) -> Void = { _ in }

    @State private var showImporter = false
    @State private var pendingRemoval: PageVaultBook?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if store.books.isEmpty {
                    emptyState
                } else {
                    ForEach(store.books) { book in
                        bookRow(book)
                    }
                }
                if let summary = store.lastImportSummary {
                    Text("Last import: \(summary)")
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("pagevault-import-measurement")
                }
            }
            .padding(24)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("PageVault")
        .task { await store.load() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                Task { for url in urls { await store.importBook(from: url) } }
            case .failure(let error):
                store.message = "That file could not be read: \(error.localizedDescription)"
            }
        }
        .alert("PageVault", isPresented: Binding(
            get: { store.message != nil },
            set: { if !$0 { store.message = nil } }
        )) {
            Button("OK") { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
        .confirmationDialog("Remove this book?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        ), titleVisibility: .visible) {
            Button("Remove copy", role: .destructive) {
                if let book = pendingRemoval { store.remove(book) }
                pendingRemoval = nil
            }
            Button("Keep", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("This deletes only PageVault's copy and your place in it. Your original file is untouched.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your reading corner")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("PDFs you add are copied here so they stay readable offline.")
                .font(.subheadline).foregroundStyle(Palette.muted)
            Button {
                showImporter = true
            } label: {
                Label(store.busy ? "Copying…" : "Add a PDF", systemImage: "plus")
            }
            .buttonStyle(ActionStyle(primary: true))
            .disabled(store.busy || !store.storageAvailable)
            .accessibilityIdentifier("import-pdf")
        }
    }

    private var emptyState: some View {
        Surface {
            Text("No books yet").font(.headline)
            Text("Add a PDF from Files or iCloud Drive to start reading.")
                .font(.subheadline).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pagevault-empty-state")
    }

    private func bookRow(_ book: PageVaultBook) -> some View {
        NavigationLink {
            if let url = store.documentURL(for: book) {
                PageVaultReaderView(book: book, url: url, store: store,
                                    onReadingSessionChange: onReadingSessionChange)
            } else {
                ContentUnavailableView("Copy unavailable", systemImage: "exclamationmark.triangle",
                                       description: Text("PageVault's copy of this book is missing."))
            }
        } label: {
            Surface {
                Text(book.title).font(.system(.headline, design: .rounded)).lineLimit(2)
                AdaptiveRow {
                    Text(book.progressLabel)
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.lime)
                } trailing: {
                    Text(ByteCountFormatter.string(fromByteCount: book.byteCount, countStyle: .file))
                        .font(.caption).foregroundStyle(Palette.muted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-book-\(book.id.uuidString)")
        .contextMenu {
            Button("Remove from library", role: .destructive) { pendingRemoval = book }
        }
    }
}
