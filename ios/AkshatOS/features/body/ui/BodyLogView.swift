import SwiftUI

/// Today's weight, this week's measurements, the estimates, and the way into photos and history.
struct BodyLogView: View {
    @ObservedObject var store: BodyLogStore
    @State private var weightText = ""
    @State private var measuring: BodyMeasurement?
    @State private var measuringNew = false
    @State private var showSettings = false
    @FocusState private var weightFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline).foregroundStyle(Palette.muted)
                weightCard
                measurementCard
                estimatesCard
                link("Photos", detail: store.photosDue ? "Due" : photoCount, id: "open-body-photos") {
                    BodyPhotosView(store: store)
                }
                link("History", detail: historyCount, id: "open-body-history") {
                    BodyHistoryView(store: store)
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
        .navigationTitle("Body")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Body settings")
                    .accessibilityIdentifier("body-settings")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { weightFocused = false }
            }
        }
        .sheet(isPresented: $measuringNew) { BodyMeasurementForm(store: store, editing: nil) }
        .sheet(item: $measuring) { BodyMeasurementForm(store: store, editing: $0) }
        .sheet(isPresented: $showSettings) { BodySettingsView(store: store) }
        .alert("Body", isPresented: Binding(get: { store.message != nil },
                                            set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var weightCard: some View {
        Surface {
            AdaptiveRow {
                Text("Weight").font(.headline)
            } trailing: {
                Text(store.todayWeight.map { "\(Self.pounds($0.pounds)) today" } ?? "Not logged today")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 12) {
                TextField("lb", text: $weightText)
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
                    .font(.title3.monospacedDigit())
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Palette.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("body-weight-field")
                Button(store.todayWeight == nil ? "Log" : "Update") {
                    guard let value = Double(weightText.replacingOccurrences(of: ",", with: ".")) else {
                        store.message = BodyLogError.invalidWeight.localizedDescription
                        return
                    }
                    store.logWeight(value)
                    weightText = ""
                    weightFocused = false
                }
                .buttonStyle(ActionStyle(primary: true))
                .frame(width: 110)
                .disabled(weightText.isEmpty || !store.storageAvailable)
                .accessibilityIdentifier("log-weight")
            }
            row("7-day average", store.rollingAverage.map(Self.pounds) ?? "—")
            if let week = store.weekChange {
                row("This week", Self.pounds(week.average) + (week.change.map { " · \(Self.signed($0))" } ?? ""))
            }
            Text("Weigh in each morning after the bathroom, before food or water. The weekly trend matters, not one day.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }

    private var measurementCard: some View {
        Surface {
            Text("Measurements").font(.headline)
            if let session = store.thisWeekMeasurement {
                Text("Measured \(Self.dayTitle(session.day))").font(.subheadline).foregroundStyle(Palette.muted)
                ForEach(BodySite.allCases) { site in
                    if let value = session.value(site) {
                        row(site.title, "\(Self.inches(value))"
                            + (store.change(for: site, in: session).map { " · \(Self.signed($0))" } ?? ""))
                    }
                }
                Button("Edit") { measuring = session }
                    .buttonStyle(ActionStyle())
            } else {
                Text(store.latestMeasurement.map { "Last measured \(Self.dayTitle($0.day))." }
                     ?? "Not measured yet. It takes about three minutes with a tape.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                Button("Measure") { measuringNew = true }
                    .buttonStyle(ActionStyle(primary: true))
                    .disabled(!store.storageAvailable)
                    .accessibilityIdentifier("measure-body")
            }
        }
    }

    @ViewBuilder private var estimatesCard: some View {
        Surface {
            Text("Estimates").font(.headline)
            if store.heightInches == nil {
                Text("Add your height in settings to see a body-fat estimate and waist-to-height ratio.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                row("Body fat (Navy estimate)", store.bodyFatEstimate.map { String(format: "%.1f%%", $0) } ?? "Needs waist and neck")
                row("Waist-to-height", store.waistToHeight.map { String(format: "%.2f", $0) } ?? "Needs waist")
                Text("Estimated from your latest waist and neck. Follow the trend, not the exact number.")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        AdaptiveRow {
            Text(label).font(.subheadline)
        } trailing: {
            Text(value).font(.subheadline.monospacedDigit()).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private func link<Destination: View>(_ title: String, detail: String, id: String,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink { destination() } label: {
            Surface {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.muted).accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var photoCount: String {
        store.photoRecords.count == 1 ? "1 photo" : "\(store.photoRecords.count) photos"
    }

    private var historyCount: String {
        store.measurements.count == 1 ? "1 session" : "\(store.measurements.count) sessions"
    }

    static func pounds(_ value: Double) -> String { String(format: "%.1f lb", value) }
    static func inches(_ value: Double) -> String { "\(BodyLog.number(value)) in" }
    /// "+0.3" / "−0.3", with a true minus sign.
    static func signed(_ value: Double) -> String {
        let text = BodyLog.number(abs(value))
        if abs(value) < 0.005 { return "±0" }
        return value > 0 ? "+\(text)" : "−\(text)"
    }

    static func dayTitle(_ day: String) -> String {
        guard let date = BodyLog.date(fromDay: day, calendar: .current) else { return day }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
