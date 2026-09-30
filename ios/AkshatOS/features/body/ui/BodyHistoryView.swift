import SwiftUI

/// Every tape session, week and weigh-in, one dropdown per month with the newest open.
struct BodyHistoryView: View {
    @ObservedObject var store: BodyLogStore
    @State private var openMonths = OpenMonths()

    var body: some View {
        let months = BodyLog.byMonth(measurements: store.measurements, weeks: store.weeks, weights: store.weights)
        List {
            if months.isEmpty {
                Text("No measurements or weigh-ins yet.").foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("body-history-empty")
            }
            ForEach(months) { month in
                MonthGroup(title: MonthKey.title(month.id), summary: summary(month),
                           isExpanded: $openMonths.month(month.id)) {
                    if !month.measurements.isEmpty {
                        subheading("Measurements")
                        ForEach(month.measurements) { session in
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
                    if !month.weeks.isEmpty {
                        subheading("Weekly weight")
                        ForEach(month.weeks) { week in
                            AdaptiveRow {
                                Text("Week of \(BodyLogView.dayTitle(week.start))")
                            } trailing: {
                                Text("\(BodyLogView.pounds(week.average)) · \(week.count) day\(week.count == 1 ? "" : "s")")
                                    .monospacedDigit().foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    if !month.weights.isEmpty {
                        subheading("Weigh-ins")
                        ForEach(month.weights) { entry in
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
                .accessibilityIdentifier("body-month-\(month.id)")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { openMonths.seed(newest: months.first?.id) }
    }

    private func summary(_ month: BodyHistoryMonth) -> String {
        var parts: [String] = []
        if !month.measurements.isEmpty {
            parts.append(month.measurements.count == 1 ? "1 measurement" : "\(month.measurements.count) measurements")
        }
        if !month.weights.isEmpty {
            parts.append(month.weights.count == 1 ? "1 weigh-in" : "\(month.weights.count) weigh-ins")
        }
        return parts.joined(separator: " · ")
    }

    private func subheading(_ title: String) -> some View {
        Text(title).font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
            .textCase(.uppercase)
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
