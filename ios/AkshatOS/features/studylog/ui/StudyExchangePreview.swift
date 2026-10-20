import SwiftUI

struct StudyExchangePreview: View {
    @ObservedObject var store: StudyLogStore
    let files: [Data]
    @Environment(\.dismiss) private var dismiss
    private var preview: Result<(segments: [StudySegment], added: Int), Error> {
        Result { try store.exchangePreview(files) }
    }
    var body: some View {
        NavigationStack {
            List {
                switch preview {
                case .success(let value):
                    Section {
                        LabeledContent("New laptop sessions", value: "\(value.added)")
                        Text("Existing phone records stay intact. Importing the same session again adds no time. Sessions crossing 03:00 join the appropriate study days.")
                        Text("Finished sessions are read-only in this first exchange version. Changed records and overlaps stop the import; missing records never delete history.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("Import finished sessions") { if store.importExchange(files) { dismiss() } }
                            .accessibilityIdentifier("confirm-study-exchange")
                    }
                case .failure(let error):
                    Section("Import stopped") {
                        Text(error.localizedDescription)
                        Text("Nothing was imported. Your existing study history is unchanged. Close this preview and choose another study file. Finished records cannot be corrected through this exchange.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }.personalList().navigationTitle("Review laptop study")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                .personalMessage("Study import", message: $store.message)
        }
    }
}
