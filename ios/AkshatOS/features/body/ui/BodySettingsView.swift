import SwiftUI
import UniformTypeIdentifiers

/// Height, measurement day, the weekly reminder, and your data.
struct BodySettingsView: View {
    @ObservedObject var store: BodyLogStore
    @Environment(\.dismiss) private var dismiss
    @State private var heightText = ""
    @State private var stagedBackup: URL?
    @State private var showMover = false
    @State private var csv: BodyCSVDocument?
    @State private var showCSVExporter = false
    @State private var showImporter = false
    @State private var pendingRestore: URL?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("inches", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                            .onSubmit(saveHeight)
                            .accessibilityIdentifier("body-height")
                        Text("in").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Used only for the body-fat estimate and waist-to-height ratio. It stays on this phone.")
                }
                Section {
                    Picker("Measurement day", selection: $store.measurementWeekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(Calendar.current.weekdaySymbols[day - 1]).tag(day)
                        }
                    }
                    Toggle("Weekly reminder", isOn: Binding(
                        get: { store.reminderEnabled },
                        set: { enabled in Task { await store.setReminder(enabled: enabled) } }))
                        .accessibilityIdentifier("body-reminder")
                    if store.reminderEnabled {
                        Picker("Time", selection: $store.reminderHour) {
                            ForEach(5...12, id: \.self) { hour in
                                Text(hour == 12 ? "12:00 PM" : "\(hour):00 AM").tag(hour)
                            }
                        }
                    }
                } footer: {
                    Text("Weekly weight averages also start on this day, so a week's average and its measurements line up.")
                }
                Section {
                    Button("Export backup") {
                        do {
                            stagedBackup = try store.stageBackup()
                            showMover = true
                        } catch {
                            store.message = "The backup could not be prepared: \(error.localizedDescription)"
                        }
                    }
                    Button("Export CSV") {
                        csv = BodyCSVDocument(data: store.csvData())
                        showCSVExporter = true
                    }
                    Button("Restore backup") { showImporter = true }
                } header: {
                    Text("Your data")
                } footer: {
                    Text("The backup is a folder with every measurement, weigh-in and photo. Uninstalling AkshatOS deletes them from the phone, so keep a backup somewhere else. CSV is one row per day for spreadsheets.")
                }
            }
            .navigationTitle("Body settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveHeight()
                        dismiss()
                    }
                }
            }
            .onAppear { heightText = store.heightInches.map(BodyLog.number) ?? "" }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder, .json]) { result in
                if case .success(let url) = result { pendingRestore = url }
            }
            .fileExporter(isPresented: $showCSVExporter, document: csv, contentType: .commaSeparatedText,
                          defaultFilename: "akshatos-body") { _ in csv = nil }
            .alert("Replace your body data?", isPresented: Binding(
                get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
                Button("Replace", role: .destructive) {
                    if let url = pendingRestore { store.restore(from: url) }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("Every current weigh-in, measurement and photo is replaced by the backup. Export first if you need what is here now.")
            }
        }
        .fileMover(isPresented: $showMover, file: stagedBackup) { _ in stagedBackup = nil }
    }

    private func saveHeight() {
        let text = heightText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        if text.isEmpty { store.heightInches = nil; return }
        guard let value = Double(text), (36...96).contains(value) else {
            store.message = "Enter your height in inches, between 36 and 96."
            return
        }
        store.heightInches = value
    }
}

struct BodyCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
