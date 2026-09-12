import SwiftUI

/// Every book you have kept lines from, most recently marked first.
///
/// Called Takeaways rather than Highlights because the point is what you want to carry out of a
/// book, not the marks left in it. It is a reading surface of its own: the library is for choosing
/// what to read, this is for going back to what a book gave you.
struct PageVaultTakeawaysView: View {
    @ObservedObject var store: PageVaultStore

    var body: some View {
        Group {
            if store.booksWithHighlights.isEmpty {
                ContentUnavailableView(
                    "Nothing kept yet", systemImage: "quote.opening",
                    description: Text("Highlight a line while reading and its book appears here."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(store.booksWithHighlights) { book in
                            NavigationLink {
                                PageVaultHighlightList(store: store, bookID: book.id)
                            } label: {
                                card(book)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("takeaways-book-\(book.id.uuidString)")
                        }
                    }
                    .padding(20)
                }
                .background(Palette.background.ignoresSafeArea())
            }
        }
        .navigationTitle("Takeaways")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("pagevault-takeaways")
    }

    private func card(_ book: PageVaultBook) -> some View {
        Surface {
            HStack(alignment: .top, spacing: 14) {
                PageVaultCoverView(url: store.coverURL(for: book), revision: store.coverRevision)
                    .frame(width: 54, height: 72)
                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(.headline, design: .rounded))
                        .lineLimit(2)
                    Text(book.highlights.count == 1 ? "1 passage kept"
                         : "\(book.highlights.count) passages kept")
                        .font(.caption)
                        .foregroundStyle(Palette.lime)
                    if let latest = book.highlightsInReadingOrder.last {
                        Text(latest.preview)
                            .font(.caption)
                            .foregroundStyle(Palette.muted)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
