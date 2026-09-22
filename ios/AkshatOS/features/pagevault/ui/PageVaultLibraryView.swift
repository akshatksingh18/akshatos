import SwiftUI
import UniformTypeIdentifiers

struct PageVaultLibraryView: View {
    @ObservedObject var store: PageVaultStore
    var onReadingSessionChange: (Bool) -> Void = { _ in }

    @State private var showImporter = false
    @State private var showBackup = false
    @State private var pendingRemoval: PageVaultBook?
    @State private var detail: PageVaultBook?

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
                    shelf("In progress", icon: "book.pages.fill", books: store.startedBooks)
                    shelf("Quest queue", icon: "rectangle.stack.fill", books: store.unstartedBooks)
                    shelf("Completed tomes", icon: "checkmark.seal.fill", books: store.books(with: .finished))
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
        AccentSurface(accent: Palette.aqua) {
            QuestBadge(text: "Story quest", icon: "bookmark.fill", accent: Palette.aqua)
            Text("Enter the vault.")
                .font(.system(.largeTitle, design: .rounded, weight: .black))
            Text("Bring your own worlds. PageVault keeps them offline and remembers where you left the portal open.")
                .font(.subheadline).foregroundStyle(Palette.muted)
            HStack(spacing: 10) {
                vaultStat("\(store.books.count)", store.books.count == 1 ? "BOOK" : "BOOKS", icon: "books.vertical.fill")
                vaultStat("\(keptPassageCount)", keptPassageCount == 1 ? "PASSAGE" : "PASSAGES", icon: "quote.opening")
            }
            Button {
                showImporter = true
            } label: {
                Label(store.busy ? "Opening portal…" : "Add a PDF portal", systemImage: "plus")
            }
            .buttonStyle(ActionStyle(primary: true))
            .disabled(store.busy || !store.storageAvailable)
            .accessibilityIdentifier("import-pdf")
            // Reachable with an empty library too, which is exactly the state after a clean install.
            NavigationLink {
                PageVaultTakeawaysView(store: store,
                                       onReadingSessionChange: onReadingSessionChange)
            } label: {
                Label("Open the treasure shelf", systemImage: "quote.opening")
            }
            .buttonStyle(ActionStyle())
            .accessibilityIdentifier("open-takeaways")
            Button {
                showBackup = true
            } label: {
                Label("Back up or restore", systemImage: "externaldrive")
            }
            .buttonStyle(ActionStyle())
            .accessibilityIdentifier("pagevault-backup")
        }
        .sheet(isPresented: $showBackup) { PageVaultBackupSheet(store: store) }
    }

    private var emptyState: some View {
        AccentSurface(accent: Palette.violet) {
            QuestBadge(text: "Vault empty", icon: "moon.stars.fill", accent: Palette.violet)
            Text("No books yet").font(.headline)
            Text("Drop in a PDF from Files or iCloud Drive. Your first story quest starts there.")
                .font(.subheadline).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pagevault-empty-state")
    }

    @ViewBuilder private var continueReading: some View {
        if let book = store.current {
            VStack(alignment: .leading, spacing: 12) {
                Text("CONTINUE READING")
                    .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Palette.muted)
                NavigationLink { reader(for: book) } label: {
                    AccentSurface(accent: Palette.aqua) {
                        QuestBadge(text: "Current portal", icon: "location.fill", accent: Palette.aqua)
                        HStack(alignment: .top, spacing: 16) {
                            PageVaultCoverView(url: store.coverURL(for: book),
                                               revision: store.coverRevision)
                                .frame(width: 78, height: 104)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title)
                                    .font(.system(.headline, design: .rounded)).lineLimit(3)
                                Text(book.progressLabel)
                                    .font(.caption.monospacedDigit()).foregroundStyle(Palette.lime)
                                ProgressView(value: book.progressFraction).tint(Palette.lime)
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

    @ViewBuilder private func shelf(_ title: String, icon: String, books: [PageVaultBook]) -> some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    QuestBadge(text: title, icon: icon, accent: Palette.violet)
                    Spacer()
                    Text("\(books.count)").font(.caption.monospacedDigit().weight(.bold))
                        .foregroundStyle(Palette.muted)
                }
                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                    ForEach(books) { book in
                        NavigationLink { reader(for: book) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                PageVaultCoverView(url: store.coverURL(for: book),
                                                   revision: store.coverRevision)
                                    .frame(height: 138)
                                Text(book.title).font(.caption.weight(.semibold)).lineLimit(2)
                                Text(book.progressLabel)
                                    .font(.caption2.monospacedDigit()).foregroundStyle(Palette.muted)
                            }
                            .padding(10)
                            .background(Palette.cardGradient, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("open-book-\(book.id.uuidString)")
                        .contextMenu { menu(for: book) }
                    }
                }
            }
        }
    }

    private var keptPassageCount: Int {
        store.books.reduce(0) { $0 + $1.highlights.count }
    }

    private func vaultStat(_ value: String, _ label: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Palette.aqua).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.headline.monospacedDigit())
                Text(label).font(.caption2.weight(.bold)).tracking(0.8).foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.black.opacity(0.13), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func menu(for book: PageVaultBook) -> some View {
        Button("Book details") { detail = book }
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
