import SwiftUI
import UniformTypeIdentifiers

struct PageVaultLibraryView: View {
    @ObservedObject var store: PageVaultStore
    var onReadingSessionChange: (Bool) -> Void = { _ in }

    @State private var showImporter = false
    @State private var showBackup = false
    @State private var pendingRemoval: PageVaultBook?
    @State private var detail: PageVaultBook?
    /// The cover a dragged book is hovering over, outlined so the drop place is clear.
    @State private var dropTarget: UUID?

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if store.books.isEmpty {
                    emptyState
                } else {
                    continueReading
                    // Half-read books get their own shelf rather than sitting among unopened ones.
                    shelf("In progress", books: store.startedBooks)
                    shelf("Want to read", books: store.unstartedBooks, reorderable: true)
                    shelf("Finished", books: store.books(with: .finished))
                }
                if let summary = store.lastImportSummary {
                    Text("Last import: \(summary)")
                        .font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("pagevault-import-measurement")
                }
            }
            .padding(24)
        }
        .background(AppBackdrop())
        .navigationTitle("PageVault")
        .task { await store.load() }
        .sheet(item: $detail) { book in
            PageVaultBookSheet(store: store, bookID: book.id)
        }
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
        VStack(alignment: .leading, spacing: 12) {
            if !store.books.isEmpty {
                Text(librarySummary).font(.subheadline).foregroundStyle(Palette.muted)
            }
            Button {
                showImporter = true
            } label: {
                Text(store.busy ? "Adding…" : "Add PDF")
            }
            .buttonStyle(ActionStyle(primary: true))
            .disabled(store.busy || !store.storageAvailable)
            .accessibilityIdentifier("import-pdf")
            HStack(spacing: 12) {
                // Reachable with an empty library too, which is exactly the state after a clean install.
                NavigationLink {
                    PageVaultTakeawaysView(store: store,
                                           onReadingSessionChange: onReadingSessionChange)
                } label: {
                    Text("Takeaways")
                }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("open-takeaways")
                Button {
                    showBackup = true
                } label: {
                    Text("Back up")
                }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("pagevault-backup")
            }
        }
        .sheet(isPresented: $showBackup) { PageVaultBackupSheet(store: store) }
    }

    private var librarySummary: String {
        let books = store.books.count == 1 ? "1 book" : "\(store.books.count) books"
        guard keptPassageCount > 0 else { return books }
        return "\(books) · \(keptPassageCount == 1 ? "1 highlight" : "\(keptPassageCount) highlights")"
    }

    private var emptyState: some View {
        Surface {
            Text("No books yet").font(.headline)
            Text("Add a PDF from Files, iCloud Drive or OneDrive.")
                .font(.subheadline).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pagevault-empty-state")
    }

    @ViewBuilder private var continueReading: some View {
        if let book = store.current {
            VStack(alignment: .leading, spacing: 12) {
                Text("Continue reading").font(.headline)
                NavigationLink { reader(for: book) } label: {
                    Surface {
                        HStack(alignment: .top, spacing: 16) {
                            PageVaultCoverView(url: store.coverURL(for: book),
                                               revision: store.coverRevision)
                                .frame(width: 78, height: 104)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title)
                                    .font(.headline).lineLimit(3)
                                Text(book.progressLabel)
                                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.accent)
                                ProgressView(value: book.progressFraction).tint(Palette.accent)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("continue-reading")
                .contextMenu { menu(for: book) }
            }
        }
    }

    /// A shelf of covers. Want to read is `reorderable`: hold a cover and drag it onto another to put
    /// it in that place, so the shelf reads in Akshat's order of what to read next.
    @ViewBuilder private func shelf(_ title: String, books: [PageVaultBook],
                                    reorderable: Bool = false) -> some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text("\(books.count)").font(.subheadline.monospacedDigit())
                        .foregroundStyle(Palette.muted)
                }
                if reorderable && books.count > 1 {
                    Text("Hold a cover and drag it to change the order.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(books) { book in
                        tile(for: book, reorderable: reorderable, shelf: books)
                    }
                }
            }
        }
    }

    @ViewBuilder private func tile(for book: PageVaultBook, reorderable: Bool,
                                   shelf books: [PageVaultBook]) -> some View {
        let link = NavigationLink { reader(for: book) } label: {
            VStack(alignment: .leading, spacing: 6) {
                PageVaultCoverView(url: store.coverURL(for: book), revision: store.coverRevision)
                    .frame(height: 138)
                Text(book.title).font(.caption.weight(.semibold)).lineLimit(2)
                Text(book.progressLabel)
                    .font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
            }
            .padding(10)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(dropTarget == book.id ? Palette.accent : .white.opacity(0.06),
                        lineWidth: dropTarget == book.id ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("open-book-\(book.id.uuidString)")
        if reorderable {
            link
                .contextMenu { menu(for: book, orderIn: books) }
                .draggable(book.id.uuidString) {
                    PageVaultCoverView(url: store.coverURL(for: book), revision: store.coverRevision)
                        .frame(width: 90, height: 120)
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let moved = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                    dropTarget = nil
                    store.moveWantToRead(moved, to: book.id)
                    return true
                } isTargeted: { over in
                    if over { dropTarget = book.id } else if dropTarget == book.id { dropTarget = nil }
                }
        } else {
            link.contextMenu { menu(for: book) }
        }
    }

    private var keptPassageCount: Int {
        store.books.reduce(0) { $0 + $1.highlights.count }
    }

    @ViewBuilder private func menu(for book: PageVaultBook, orderIn shelf: [PageVaultBook] = []) -> some View {
        Button("Book details") { detail = book }
        if shelf.count > 1 {
            if shelf.first?.id != book.id {
                Button("Move to top") { store.moveWantToRead(book.id, to: shelf.first?.id) }
            }
            if shelf.last?.id != book.id {
                Button("Move to bottom") { store.moveWantToRead(book.id, to: nil) }
            }
        }
        ForEach(PageVaultReadingStatus.allCases, id: \.self) { status in
            if status != book.status {
                Button("Mark as \(status.label.lowercased())") {
                    store.setStatus(status, for: book)
                }
            }
        }
        Button("Remove from library", role: .destructive) { pendingRemoval = book }
    }

    @ViewBuilder private func reader(for book: PageVaultBook) -> some View {
        if let url = store.documentURL(for: book) {
            PageVaultReaderView(book: book, url: url, store: store,
                                onReadingSessionChange: onReadingSessionChange)
        } else {
            ContentUnavailableView("Copy unavailable", systemImage: "exclamationmark.triangle",
                                   description: Text("PageVault's copy of this book is missing."))
                .background(Palette.background.ignoresSafeArea())
        }
    }
}

/// Loads a cached cover off the main thread. A missing cover is a normal state, not an error:
/// covers are regenerable, so the placeholder simply stands in until one exists.
struct PageVaultCoverView: View {
    let url: URL?
    let revision: Int

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "book.closed")
                    .font(.title2).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Palette.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .task(id: "\(url?.path ?? "none")#\(revision)") { await load() }
        .accessibilityHidden(true)
    }

    private func load() async {
        guard let url else { image = nil; return }
        image = await Task.detached(priority: .utility) { UIImage(contentsOfFile: url.path) }.value
    }
}
