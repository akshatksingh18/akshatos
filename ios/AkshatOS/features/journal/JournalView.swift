import SwiftUI
import Charts
import PhotosUI
import UniformTypeIdentifiers

struct JournalView: View {
    @ObservedObject var store: JournalStore
    var facts: (String) -> JournalDayFacts
    var planTomorrow: () -> Void
    @Environment(\.scenePhase) private var phase
    @State private var day = ""
    @State private var history = false
    @State private var chartWeek = true
    @State private var openMonths = OpenMonths()
    @State private var search = ""
    @State private var share: URL?
    @State private var showMover = false
    @State private var protectExport = false
    @State private var photoSelection: PhotosPickerItem?
    @State private var camera = false
    @State private var importing = false
    @State private var pendingRestore: HubBackupRestore?
    var body: some View {
        Group {
            if store.isLocked { locked }
            else if !store.available { ContentUnavailableView { Label("Journal unavailable", systemImage: "exclamationmark.lock") } actions: { Button("Retry") { store.load() } } }
            else if history { historyList }
            else { editor }
        }
        .background(HubInk.background).navigationTitle(history ? "Journal history" : "Journal")
        .tint(HubInk.copper).privacySensitive()
        .task { if day.isEmpty { day = store.today }; if !store.available { store.load() } }
        .toolbar {
            if !store.isLocked {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(history ? "Write" : "History") { history.toggle() }.accessibilityIdentifier("journal-history")
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Export this entry") { protectExport = true }
                        Button("Restore Journal backup") { importing = true }
                        if store.lockEnabled { Button("Lock Journal", systemImage: "lock") { store.lock() } }
                    } label: { Label("Journal actions", systemImage: "ellipsis.circle") }
                }
            }
        }
        .personalMessage("Journal", message: $store.message)
        .alert("Export private writing?", isPresented: $protectExport) {
            Button("Export") { Task {
                do { share = try await store.exportMarkdown(day); showMover = true }
                catch { store.message = error.localizedDescription }
            } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The saved Markdown and photos can be opened without Face ID. Choose their destination yourself.") }
        .fileMover(isPresented: $showMover, file: share) { result in
            if case .failure(let error) = result { store.message = error.localizedDescription }
            if let share { try? FileManager.default.removeItem(at: share) }; share = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            Task {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                do { pendingRestore = try await store.prepareBackupRestore(from: url) }
                catch { store.message = error.localizedDescription }
            }
        }
        .alert("Replace Journal?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("Replace", role: .destructive) {
                guard let prepared = pendingRestore else { return }; pendingRestore = nil
                Task { if case .failed(let text) = await prepared.apply() { store.message = text } }
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: { Text("This replaces Journal entries, weekly notes and photos. Back up first.") }
        .onChange(of: photoSelection) { _, selection in
            guard let selection else { return }
            let requestedDay = day
            Task {
                do { if let data = try await selection.loadTransferable(type: Data.self) { store.addPhoto(data, day: requestedDay) } }
                catch { store.message = "That photo could not be read." }
                photoSelection = nil
            }
        }
        .sheet(isPresented: $camera) {
            LocalCameraPicker { data in if let data { store.addPhoto(data, day: day) }; camera = false }.ignoresSafeArea()
        }
        .overlay {
            if phase != .active { HubInk.background.ignoresSafeArea().overlay { Label("Journal", systemImage: "lock.fill").foregroundStyle(.secondary) } }
        }
    }
    private var locked: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill").font(.largeTitle).foregroundStyle(HubInk.copper)
            Text("Your journal is locked").font(.title2)
            Button("Unlock Journal") { Task { _ = await store.authenticate() } }
                .buttonStyle(.borderedProminent).foregroundStyle(HubInk.background).accessibilityIdentifier("journal-unlock")
            Text("Face ID with device-passcode fallback").font(.footnote).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var current: JournalEntry { store.entry(day) ?? store.newEntry(day) }
    private func textBinding(_ path: WritableKeyPath<JournalEntry, String>) -> Binding<String> {
        Binding(get: { current[keyPath: path] }, set: { text in var value = current; value[keyPath: path] = text; _ = store.save(value) })
    }
    private func rating(_ path: WritableKeyPath<JournalEntry, Int?>) -> Binding<Int> {
        Binding(get: { current[keyPath: path] ?? 0 }, set: { n in var value = current; value[keyPath: path] = n == 0 ? nil : n; _ = store.save(value) })
    }
    private var editor: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text(store.clock.date(day)?.formatted(date: .complete, time: .omitted) ?? day).foregroundStyle(.secondary)
                    Spacer()
                    if day != store.today { Button("Today") { day = store.today } }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your entry").font(.subheadline).foregroundStyle(.secondary)
                    TextEditor(text: textBinding(\.text)).scrollContentBackground(.hidden)
                        .frame(minHeight: 240).accessibilityLabel("Journal entry").accessibilityIdentifier("journal-entry")
                }.padding(18).background(HubInk.surface, in: UnevenRoundedRectangle(topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 3, topTrailingRadius: 22))
                if store.unsaved { Label("Draft not saved", systemImage: "exclamationmark.triangle"); Button("Retry save") { store.retryDraft() } }
                else { Text(store.entry(day) == nil ? "No entry saved yet" : current.completedAt == nil ? "Draft saved on this iPhone" : "Done for this day").font(.caption).foregroundStyle(.secondary) }
                Button {
                    if current.completedAt == nil { var value = current; value.facts = facts(day); store.markDone(value) }
                    else { store.markDone(current) }
                } label: {
                    Label(current.completedAt == nil ? "Done for this day" : "Mark as draft", systemImage: "checkmark")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.borderedProminent).foregroundStyle(HubInk.background).disabled(!current.hasWriting || store.unsaved)
                    .accessibilityIdentifier("journal-done")
                DisclosureGroup("Writing prompts") {
                    VStack(spacing: 14) {
                        TextField("What went well?", text: textBinding(\.wentWell), axis: .vertical)
                        TextField("What would you change?", text: textBinding(\.change), axis: .vertical)
                        TextField("One thing learned", text: textBinding(\.learned), axis: .vertical)
                    }.padding(.vertical)
                }
                DisclosureGroup("Mood, energy and photos") {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Mood", selection: rating(\.mood)) { Text("Not recorded").tag(0); ForEach(1...5, id: \.self) { Text("\($0)/5").tag($0) } }
                        Picker("Energy", selection: rating(\.energy)) { Text("Not recorded").tag(0); ForEach(1...5, id: \.self) { Text("\($0)/5").tag($0) } }
                        PhotosPicker(selection: $photoSelection, matching: .images) { Label("Choose photo", systemImage: "photo") }
                        if UIImagePickerController.isSourceTypeAvailable(.camera) { Button("Take photo", systemImage: "camera") { camera = true } }
                        ForEach(current.photos, id: \.self) { name in
                            if let photo = store.photo(name) {
                                Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 220).accessibilityLabel("Journal photo")
                                Button("Remove photo", role: .destructive) { store.removePhoto(name, day: day) }
                            } else { Label("Photo unavailable", systemImage: "exclamationmark.triangle") }
                        }
                    }.padding(.vertical)
                }
                DisclosureGroup("Today’s facts") {
                    let snapshot = current.facts ?? facts(day)
                    VStack(alignment: .leading, spacing: 8) {
                        if let seconds = snapshot.studySeconds { Text("Studied \(StudyTimeDisplay.short(seconds))") }
                        else { Text("Study data unavailable") }
                        if let count = snapshot.completedTasks { Text("\(count) tasks completed") }
                        if let title = snapshot.readingTitle { Text("Reading: \(title)") }
                        Text("Snapshot: \(snapshot.capturedAt.formatted())").font(.caption).foregroundStyle(.secondary)
                        Button("Refresh facts") { store.updateFacts(facts(day)) }
                    }.padding(.vertical)
                }
                Button("Plan tomorrow’s priorities", action: planTomorrow).disabled(day != store.today)
            }.padding(22)
        }
    }
    private var historyList: some View {
        List {
            let old = store.onThisDay(store.today)
            if !old.isEmpty { Section("On this day") { ForEach(old) { historyRow($0) } } }
            Section {
                DisclosureGroup("Mood and energy") {
                    Picker("Period", selection: $chartWeek) { Text("Week").tag(true); Text("Month").tag(false) }.pickerStyle(.segmented)
                    let values = store.entries.filter { chartWeek ? store.clock.week(store.today).contains($0.day) : $0.day.hasPrefix(String(store.today.prefix(7))) }
                    if values.contains(where: { $0.mood != nil || $0.energy != nil }) {
                        Chart(values) { entry in
                            if let date = store.clock.date(entry.day), let mood = entry.mood {
                                PointMark(x: .value("Day", date), y: .value("Rating", mood)).foregroundStyle(by: .value("Measure", "Mood"))
                            }
                            if let date = store.clock.date(entry.day), let energy = entry.energy {
                                PointMark(x: .value("Day", date), y: .value("Rating", energy)).foregroundStyle(by: .value("Measure", "Energy"))
                            }
                        }.chartYScale(domain: 1...5).chartForegroundStyleScale(["Mood": HubInk.copper, "Energy": HubInk.sage]).frame(height: 160)
                        Text("Only recorded ratings appear. Tap an entry below to inspect or edit its values.").font(.caption).foregroundStyle(.secondary)
                    } else { Text("No ratings recorded in this period.").foregroundStyle(.secondary) }
                }
                Text("\(store.entries.filter { $0.day.hasPrefix(String(store.today.prefix(7))) && $0.hasWriting }.count) written entries this month").font(.subheadline)
            }
            let values = store.entries.filter { search.isEmpty || ($0.text + $0.wentWell + $0.change + $0.learned).localizedCaseInsensitiveContains(search) }
            let groups = Dictionary(grouping: values) { String($0.day.prefix(7)) }
            ForEach(groups.keys.sorted(by: >), id: \.self) { month in
                MonthGroup(title: MonthKey.title(month), summary: "\(groups[month, default: []].count) entries", isExpanded: $openMonths.month(month)) {
                    ForEach(groups[month, default: []]) { historyRow($0) }
                }
            }
            if values.isEmpty { Text(search.isEmpty ? "Your first entry starts here." : "No matching entries.").foregroundStyle(.secondary) }
        }.personalList().searchable(text: $search, prompt: "Search unlocked entries")
        .onAppear { openMonths.seed(newest: store.entries.first.map { String($0.day.prefix(7)) }) }
    }
    private func historyRow(_ entry: JournalEntry) -> some View {
        Button { day = entry.day; history = false } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(store.clock.date(entry.day)?.formatted(date: .abbreviated, time: .omitted) ?? entry.day)
                Text(entry.text.isEmpty ? entry.learned : entry.text).lineLimit(2).font(.subheadline).foregroundStyle(.secondary)
                if let mood = entry.mood { Text("Mood \(mood)/5").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}
