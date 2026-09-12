import SwiftUI

/// Searching one book's text. Results arrive as you type, and each keystroke cancels the search
/// before it. A scanned book has no text layer, so it honestly finds nothing.
struct PageVaultSearchView: View {
    @ObservedObject var store: PageVaultStore
    let book: PageVaultBook
    /// The whole hit, not just its page: the reader tints the words that matched on arrival, which
    /// needs where on the page they sit.
    var onJump: (PageVaultSearchHit) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var hits: [PageVaultSearchHit] = []
    @State private var searching = false

    var body: some View {
        NavigationStack {
            results
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $query, prompt: "Word or phrase")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                }
        }
        .task(id: query) {
            guard PageVaultSearch.isSearchable(query) else {
                hits = []
                return
            }
            searching = true
            defer { searching = false }
            let found = await store.search(query, in: book)
            guard !Task.isCancelled else { return }
            hits = found
        }
    }

    private var title: String {
        guard !hits.isEmpty else { return "Search" }
        return hits.count == 1 ? "1 result" : "\(hits.count) results"
    }

    @ViewBuilder private var results: some View {
        if !PageVaultSearch.isSearchable(query) {
            ContentUnavailableView(
                "Search this book", systemImage: "magnifyingglass",
                description: Text("Type at least two letters. A scanned book has no text to search."))
        } else if searching && hits.isEmpty {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if hits.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            List(hits) { hit in
                Button {
                    onJump(hit)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("PAGE \(hit.page + 1)")
                            .font(.caption2.weight(.bold)).tracking(1.5)
                            .foregroundStyle(Palette.muted)
                        Text(hit.snippet)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("search-hit-\(hit.id)")
            }
        }
    }
}
