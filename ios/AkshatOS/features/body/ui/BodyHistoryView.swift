import SwiftUI

/// Every tape session and every week of weigh-ins, in a lazy list.
struct BodyHistoryView: View {
    @ObservedObject var store: BodyLogStore

    var body: some View {
        List {
            Section("Measurements") {
                if store.measurements.isEmpty {
                    Text("No measurements yet.").foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("body-history-empty")
                }
                ForEach(store.measurements) { session in
                    NavigationLink {
                        BodyMeasurementDetail(store: store, measurementID: session.id)
                    } label: {
                        AdaptiveRow {
                            Text(BodyLogView.dayTitle(session.day))
                        } trailing: {
                            Text(session.value(.waistNavel).map { "Waist \(BodyLogView.inches($0))" }
                                 ?? "\(session.inches.count) sites")
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
            Section("Weekly weight") {
                if store.weeks.isEmpty {
                    Text("No weigh-ins yet.").foregroundStyle(Palette.muted)
                }
                ForEach(store.weeks) { week in
                    AdaptiveRow {
                        Text("Week of \(BodyLogView.dayTitle(week.start))")
                    } trailing: {
                        Text("\(BodyLogView.pounds(week.average)) · \(week.count) day\(week.count == 1 ? "" : "s")")
                            .monospacedDigit().foregroundStyle(Palette.muted)
                    }
                }
            }
            Section("Weigh-ins") {
                ForEach(store.weights) { entry in
                    AdaptiveRow {
                        Text(BodyLogView.dayTitle(entry.day))
                    } trailing: {
                        Text(BodyLogView.pounds(entry.pounds)).monospacedDigit().foregroundStyle(Palette.muted)
                    }
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.deleteWeight(entry) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// One session with every site and its change since the session before.
struct BodyMeasurementDetail: View {
    @ObservedObject var store: BodyLogStore
    let measurementID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingDelete = false

    var body: some View {
        let session = store.measurements.first { $0.id == measurementID }
        List {
            if let session {
                ForEach(BodySite.allCases) { site in
                    AdaptiveRow {
                        Text(site.title)
                    } trailing: {
                        Text(session.value(site).map { value in
                            BodyLogView.inches(value)
                                + (store.change(for: site, in: session).map { " · \(BodyLogView.signed($0))" } ?? "")
                        } ?? "—")
                        .monospacedDigit().foregroundStyle(Palette.muted)
                    }
                }
                Section {
                    Button("Edit") { editing = true }
                    Button("Delete", role: .destructive) { confirmingDelete = true }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle(session.map { BodyLogView.dayTitle($0.day) } ?? "Measurement")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            if let session { BodyMeasurementForm(store: store, editing: session) }
        }
        .confirmationDialog("Delete these measurements?", isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let session { store.deleteMeasurement(session) }
                dismiss()
            }
        }
    }
}
