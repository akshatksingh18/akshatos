import SwiftUI
import UniformTypeIdentifiers

struct StudyCorrectionView: View {
    @ObservedObject var store: StudyLogStore
    @State var segment: StudySegment
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Started", selection: $segment.start, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                DatePicker("Actually stopped", selection: Binding(get: { segment.end ?? Date() }, set: { segment.end = $0 }), in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                TextField("Topic", text: Binding(get: { segment.topic ?? "" }, set: { segment.topic = $0.isEmpty ? nil : $0 }))
                Picker("Roadmap time type", selection: Binding(get: { segment.roadmapType ?? "other" }, set: { segment.roadmapType = $0 })) { ForEach(StudySegment.roadmapTypes, id: \.self) { Text($0).tag($0) } }
                TextField("Note", text: Binding(get: { segment.note ?? "" }, set: { segment.note = $0.isEmpty ? nil : $0 }), axis: .vertical)
                Text("This edits the whole original block, including every part that crosses 3 AM. Overlapping or future blocks cannot be saved.").font(.footnote).foregroundStyle(.secondary)
                if store.log.segments.contains(where: { $0.id == segment.id && !$0.isRunning }) {
                    Button("Delete block", role: .destructive) { store.removeSegment(segment.id); if store.message == nil { dismiss() } }
                }
            }.personalList().navigationTitle("Study block")
            .disabled(segment.exchangeOriginID != nil)
            .safeAreaInset(edge: .bottom) {
                if segment.exchangeOriginID != nil {
                    Text("Imported from Laptop · read-only in this exchange version.")
                        .font(.footnote).padding().frame(maxWidth: .infinity).background(HubInk.background)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    var value = segment
                    if value.end == nil { value.end = Date() }
                    if store.saveSegment(value) { dismiss() }
                }.disabled(segment.exchangeOriginID != nil) }
            }.personalMessage("Study correction", message: $store.message)
        }
    }
}

struct StudyRunningRestoreView: View {
    @ObservedObject var store: StudyLogStore
    let review: StudyRunningRestoreReview
    @State private var end = Date()
    var body: some View {
        NavigationStack {
            Form {
                Text("A backed-up running timer cannot prove how long you studied. Choose when you actually stopped. It will restore as a finished block.")
                LabeledContent("Started", value: review.start.formatted())
                DatePicker("Actually stopped", selection: $end, in: review.start...max(review.start, Date()), displayedComponents: [.date, .hourAndMinute])
            }.personalList().navigationTitle("Confirm running time")
            .onAppear { end = review.suggestedEnd }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel restore") { store.finishRunningRestore(nil) } }
                ToolbarItem(placement: .confirmationAction) { Button("Use this end") { store.finishRunningRestore(end) } }
            }
        }.interactiveDismissDisabled()
    }
}

struct StudyPreferencesView: View {
    @ObservedObject var store: StudyLogStore
    @State private var exporting = false
    @State private var document: PortableDocument?
    @State private var target = 6.0
    @State private var first = 2.0
    @State private var second = 4.0
    var body: some View {
        Form {
            Section("Future study days") {
                Stepper("Aim: \(target.formatted()) hours", value: $target, in: 0.5...16, step: 0.5)
                Stepper("First mark: \(first.formatted()) hours", value: $first, in: 0...16, step: 0.5)
                Stepper("Second mark: \(second.formatted()) hours", value: $second, in: 0...16, step: 0.5)
                Button("Save target and marks") {
                    store.updateSettings(target: Int(target * 3600), floor: Int(first * 3600), goal: Int(second * 3600))
                    target = Double(store.settings.target) / 3600; first = Double(store.settings.floor) / 3600; second = Double(store.settings.goal) / 3600
                }
                Text("The first block of a day saves that day’s aim. Changes apply to future days; earlier targets stay as recorded. Marks are kept in order within the aim.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Roadmap export") { Picker("Default time type", selection: Binding(get: { store.defaultRoadmapType }, set: { store.setDefaultRoadmapType($0) })) { ForEach(StudySegment.roadmapTypes, id: \.self) { Text($0).tag($0) } } }
            Section("Your study data") {
                NavigationLink("Blocks, backup and restore") { StudyLogView(store: store) }
                Button("Export study CSV") {
                    do { document = PortableDocument(data: try store.csvData()); exporting = true }
                    catch { store.message = error.localizedDescription }
                }
            }
            Section("Activity day") { Text("3 AM to 3 AM · weeks start Monday. New blocks retain the time zone they began in; older blocks keep the existing local-time interpretation.") }
        }.personalList().navigationTitle("Study settings")
        .fileExporter(isPresented: $exporting, document: document, contentType: .commaSeparatedText, defaultFilename: "study-blocks") { result in
            if case .failure(let error) = result { store.message = error.localizedDescription }
        }
        .personalMessage("Study settings", message: $store.message)
        .onAppear { target = Double(store.settings.target) / 3600; first = Double(store.settings.floor) / 3600; second = Double(store.settings.goal) / 3600 }
    }
}
