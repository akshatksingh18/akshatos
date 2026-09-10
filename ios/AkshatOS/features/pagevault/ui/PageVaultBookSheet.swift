import SwiftUI

/// Reading status, the daily page goal, and bookmarks for one book. Reads live store state so a
/// status change made here is reflected immediately, including the single-Reading-book demotion.
struct PageVaultBookSheet: View {
    @ObservedObject var store: PageVaultStore
    let bookID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var goal = 0

    private var book: PageVaultBook? { store.book(id: bookID) }

    var body: some View {
        NavigationStack {
            Group {
                if let book {
                    List {
                        statusSection(book)
                        goalSection(book)
                        bookmarksSection(book)
                        detailsSection(book)
                    }
                } else {
                    ContentUnavailableView("Book removed", systemImage: "book.closed",
                                           description: Text("This book is no longer in your library."))
                }
            }
            .navigationTitle(book?.title ?? "Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .onAppear { goal = book?.dailyPageGoal ?? 0 }
    }

    private func statusSection(_ book: PageVaultBook) -> some View {
        Section("Status") {
            ForEach(PageVaultReadingStatus.allCases, id: \.self) { status in
                Button {
                    store.setStatus(status, for: book)
                } label: {
                    HStack {
                        Text(status.label)
                        Spacer()
                        if book.status == status {
                            Image(systemName: "checkmark").foregroundStyle(Palette.lime)
                        }
                    }
                }
                .accessibilityIdentifier("status-\(status.rawValue)")
            }
            if book.status != .reading, store.current != nil {
                Text("Only one book is Reading at a time. Choosing Reading here moves the current one back to Want to read.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    private func goalSection(_ book: PageVaultBook) -> some View {
        Section("Daily page goal") {
            Stepper(value: $goal, in: 0...200, step: 1) {
                Text(goal > 0 ? "\(goal) pages a day" : "No goal")
                    .monospacedDigit()
            }
            .accessibilityIdentifier("daily-page-goal")
            .onChange(of: goal) { _, value in
                store.setDailyGoal(value > 0 ? value : nil, for: book)
            }
            Text(book.status == .reading
                 ? "Reading this many pages counts today toward your streak."
                 : "The goal starts counting once this book is the one you are Reading.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder private func bookmarksSection(_ book: PageVaultBook) -> some View {
        Section("Bookmarks") {
            if book.bookmarks.isEmpty {
                Text("No bookmarks yet. Use the bookmark button while reading.")
                    .font(.caption).foregroundStyle(Palette.muted)
            } else {
                ForEach(book.bookmarks) { bookmark in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Page \(bookmark.page + 1)").font(.subheadline.monospacedDigit())
                        if let note = bookmark.note {
                            Text(note).font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        store.removeBookmark(book, id: book.bookmarks[index].id)
                    }
                }
            }
        }
    }

    private func detailsSection(_ book: PageVaultBook) -> some View {
        Section("This copy") {
            LabeledContent("Pages", value: "\(book.pageCount)")
            LabeledContent("Size", value: ByteCountFormatter.string(fromByteCount: book.byteCount,
                                                                    countStyle: .file))
            LabeledContent("Added", value: book.addedAt.formatted(date: .abbreviated, time: .omitted))
            if let opened = book.lastOpenedAt {
                LabeledContent("Last read", value: opened.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }
}
