import SwiftUI

/// The weekly tape session: every site with where the tape goes. Blank sites are skipped.
struct BodyMeasurementForm: View {
    @ObservedObject var store: BodyLogStore
    let editing: BodyMeasurement?
    @Environment(\.dismiss) private var dismiss
    @State private var values: [BodySite: String] = [:]
    @State private var problem: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(BodySite.allCases) { site in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(site.title)
                                Spacer()
                                TextField("in", text: binding(site))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 90)
                                    .accessibilityIdentifier("body-site-\(site.rawValue)")
                            }
                            Text(site.guidance).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                } footer: {
                    Text("Measure on the same morning each week, before eating, with the tape snug but not pressing into the skin. Leave a site blank to skip it.")
                }
                if let problem {
                    Section { Text(problem).foregroundStyle(.red) }
                }
            }
            .navigationTitle(editing == nil ? "Measure" : "Edit measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.accessibilityIdentifier("save-body-measurement")
                }
            }
            .onAppear {
                guard let editing, values.isEmpty else { return }
                for site in BodySite.allCases {
                    if let value = editing.value(site) { values[site] = BodyLog.number(value) }
                }
            }
        }
    }

    private func binding(_ site: BodySite) -> Binding<String> {
        Binding(get: { values[site] ?? "" }, set: { values[site] = $0 })
    }

    private func save() {
        var parsed: [BodySite: Double] = [:]
        for site in BodySite.allCases {
            let text = (values[site] ?? "").trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ",", with: ".")
            guard !text.isEmpty else { continue }
            guard let value = Double(text) else {
                problem = "\(site.title) is not a number."
                return
            }
            parsed[site] = value
        }
        do {
            _ = try BodyLog.validatedInches(parsed)
        } catch {
            problem = error.localizedDescription
            return
        }
        if store.saveMeasurement(parsed, editing: editing) { dismiss() }
    }
}
