import SwiftUI
import UniformTypeIdentifiers

struct PageVaultLibraryView: View {
    @ObservedObject var store: PageVaultStore
    var onReadingSessionChange: (Bool) -> Void = { _ in }

    @State private var showImporter = false
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
                    streakCard
                    continueReading
                    shelf("Want to read", books: store.books(with: .wantToRead))
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
        .background(Palette.background.ignoresSafeArea())
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
            Text("This deletes only PageVault's copy, your place, bookmarks and streak history for it. Your original file is untouched.")
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

    @ViewBuilder private var streakCard: some View {
        let streak = store.streak
        Surface {
            AdaptiveRow {
                Label("\(streak.current) day streak", systemImage: "flame")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(streak.current > 0 ? Palette.lime : Palette.muted)
            } trailing: {
                Text(streak.best > 0 ? "Best \(streak.best)" : "No streak yet")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            if streak.todayGoal > 0 {
                ProgressView(value: Double(min(streak.todayPagesRead, streak.todayGoal)),
                             total: Double(streak.todayGoal))
                    .tint(Palette.lime)
                Text(streak.todayMet
                     ? "Today is done: \(streak.todayPagesRead) of \(streak.todayGoal) pages."
                     : "\(streak.todayPagesRead) of \(streak.todayGoal) pages today.")
                    .font(.caption).foregroundStyle(streak.isAtRisk ? Palette.muted : Palette.lime)
                    .accessibilityIdentifier("streak-today")
            } else if let current = store.current {
                Text("Set a daily page goal for \(current.title) to start a streak.")
                    .font(.caption).foregroundStyle(Palette.muted)
            } else {
                Text("Mark a book as Reading and give it a daily page goal to start a streak.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .accessibilityIdentifier("streak-card")
    }

    @ViewBuilder private var continueReading: some View {
        if let book = store.current {
            VStack(alignment: .leading, spacing: 12) {
                Text("CONTINUE READING")
                    .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Palette.muted)
                NavigationLink { reader(for: book) } label: {
                    Surface {
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
                                if let goal = book.dailyPageGoal {
                                    Text("\(goal) pages a day").font(.caption2)
                                        .foregroundStyle(Palette.muted)
                                }
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

    @ViewBuilder private func shelf(_ title: String, books: [PageVaultBook]) -> some View {
        if !books.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Palette.muted)
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
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("open-book-\(book.id.uuidString)")
                        .contextMenu { menu(for: book) }
                    }
                }
            }
        }
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
