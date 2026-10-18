import SwiftUI
import UniformTypeIdentifiers

struct TodoView: View {
    @ObservedObject var store: TodoStore
    @FocusState private var quickAddFocused: Bool
    @State private var afterStudy = false
    @State private var quickAdd = ""
    @State private var search = ""
    @State private var editing: TodoItem?
    @State private var planning = false
    @State private var planDay = ""
    @State private var export = false
    @State private var document: PortableDocument?
    @State private var exportType = UTType.json
    @State private var importing = false
    @State private var pending: TodoState?
    @State private var routines = false
    var body: some View {
        List {
            Picker("List", selection: $afterStudy) {
                Text("My To-do").tag(false); Text("After study · \(store.state.thoughts.count)").tag(true)
            }.pickerStyle(.segmented).listRowBackground(Color.clear)
            if !store.available {
                Section { Text("Your list is unavailable."); Button("Retry") { store.load() } }
            } else if afterStudy {
                Section { ThoughtCaptureField { store.park($0) } }
                if store.state.thoughts.isEmpty { Text("Nothing parked yet.").foregroundStyle(.secondary) }
                ForEach(store.state.thoughts.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) }) { thought in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(thought.text)
                        HStack {
                            Button("Done") { store.sortThought(thought.id, move: false) }.buttonStyle(.bordered)
                            Button("Move to My To-do") { store.sortThought(thought.id, move: true) }.buttonStyle(.bordered)
                        }
                    }.swipeActions { Button("Delete", role: .destructive) { store.sortThought(thought.id, move: false) } }
                }
            } else {
                Section {
                    HStack {
                        TextField("Add a task", text: $quickAdd,
                                  prompt: Text("e.g. read tomorrow 5pm").foregroundStyle(HubInk.sage))
                            .focused($quickAddFocused).onSubmit(add).accessibilityIdentifier("todo-quick-add")
                        Button(action: add) { Image(systemName: "plus.circle.fill").frame(minWidth: 44, minHeight: 44) }
                            .accessibilityLabel("Add task").accessibilityIdentifier("todo-add")
                    }
                } header: { Text("Add a task") }
                Section {
                    let priorities = store.priorities(store.today)
                    if priorities.isEmpty { Text("No priorities chosen.").foregroundStyle(.secondary) }
                    ForEach(priorities) { row($0) }
                    Button("Choose up to three") { planDay = store.today; planning = true }
                } header: { Text("Today’s priorities") }
                taskSection("Due and overdue", items: matching.filter { $0.completedAt == nil && $0.due != nil && $0.due! <= Date() })
                taskSection("Later", items: matching.filter { $0.completedAt == nil && ($0.due ?? .distantPast) > Date() })
                taskSection("Undated", items: matching.filter { $0.completedAt == nil && $0.due == nil })
                Section {
                    DisclosureGroup("Done · \(matching.filter { $0.completedAt != nil }.count)") {
                        let done = Dictionary(grouping: matching.filter { $0.completedAt != nil }) { store.clock.key($0.completedAt!) }
                        ForEach(done.keys.sorted(by: >), id: \.self) { day in
                            Text(store.clock.date(day)?.formatted(date: .abbreviated, time: .omitted) ?? day).font(.caption).foregroundStyle(.secondary)
                            ForEach(done[day, default: []].sorted { $0.completedAt! > $1.completedAt! }) { row($0) }
                        }
                    }
                }
                if store.undoAvailable { Button("Undo completion") { store.undo() }.accessibilityIdentifier("todo-undo") }
            }
        }
        .personalList().navigationTitle("To-do")
        .searchable(text: $search, prompt: "Tasks and parked thoughts")
        .task { if !store.available { store.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("New task", systemImage: "plus") { editing = TodoItem(title: "") }
                    Button("Daily routine", systemImage: "checklist") { routines = true }
                    Button("Plan tomorrow", systemImage: "calendar") { planDay = store.clock.shifted(store.today, by: 1) ?? store.today; planning = true }
                    Button("Export backup") { prepareExport(.json) }
                    Button("Export task CSV") { prepareExport(.commaSeparatedText) }
                    Button("Restore backup") { importing = true }
                } label: { Label("More", systemImage: "ellipsis.circle") }
            }
        }
        .sheet(item: $editing) { item in TodoEditor(store: store, item: item) }
        .sheet(isPresented: $routines) { RoutineManager(store: store) }
        .sheet(isPresented: $planning) { PriorityPicker(store: store, day: planDay) }
        .personalMessage("To-do", message: $store.message)
        .fileExporter(isPresented: $export, document: document, contentType: exportType, defaultFilename: "akshatos-todo") { result in
            if case .failure(let error) = result { store.message = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(), scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                pending = try LocalDataCoding.decode(TodoState.self, Data(contentsOf: url)).validated()
            } catch { store.message = error.localizedDescription }
        }
        .alert("Replace To-do?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Replace", role: .destructive) { if let pending { _ = store.commit(pending, replacingUnavailable: true) }; pending = nil }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { Text("This replaces tasks, parked thoughts, priority plans and routine history. A backup made before routines were added clears the routine too. Export your current backup first.") }
    }
    private var matching: [TodoItem] {
        store.visible.filter { search.isEmpty || ($0.title + " " + $0.note + " " + $0.area).localizedCaseInsensitiveContains(search) }
    }
    @ViewBuilder private func taskSection(_ title: String, items: [TodoItem]) -> some View {
        if !items.isEmpty { Section(title) { ForEach(items.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }) { row($0) } } }
    }
    private func row(_ task: TodoItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { store.toggle(task.id) } label: {
                Image(systemName: task.completedAt == nil ? "circle" : "checkmark.circle.fill")
                    .font(.title3).foregroundStyle(task.completedAt == nil ? HubInk.copper : HubInk.sage)
                    .frame(minWidth: 44, minHeight: 44)
            }.buttonStyle(.plain).disabled(task.completedAt != nil || task.archivedAt != nil).accessibilityLabel(task.completedAt == nil ? "Complete \(task.title)" : "Completed \(task.title)")
            Button { editing = task } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title).foregroundStyle(task.completedAt == nil ? .primary : .secondary)
                    if let due = task.due {
                        Text(due.formatted(date: .abbreviated, time: task.hasTime ? .shortened : .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if !task.area.isEmpty { Text(task.area).font(.caption).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain)
        }
        .contextMenu {
            if task.completedAt == nil { Button("Choose for today") { store.choose(task.id, day: store.today) } }
            if store.plan(store.today)?.selected.contains(task.id) == true { Button("Remove from today") { store.removePriority(task.id, day: store.today) } }
        }
        .swipeActions { Button("Archive", role: .destructive) { store.archive(task.id) } }
    }
    private func add() { if store.add(quickAdd) { quickAdd = ""; quickAddFocused = false } }
    private func prepareExport(_ type: UTType) {
        guard store.available else { store.message = "Load To-do before exporting."; return }
        do { document = PortableDocument(data: type == .json ? try LocalDataCoding.encode(store.state) : store.csv()); exportType = type; export = true }
        catch { store.message = error.localizedDescription }
    }
}

struct PriorityPicker: View {
    @ObservedObject var store: TodoStore
    let day: String
    @Environment(\.dismiss) private var dismiss
    @State private var newTask = ""
    var body: some View {
        NavigationStack {
            List {
                Text(store.clock.date(day)?.formatted(date: .complete, time: .omitted) ?? day).foregroundStyle(.secondary)
                HStack { TextField("Add a task", text: $newTask).onSubmit { if store.add(newTask) { newTask = "" } }; Button("Add") { if store.add(newTask) { newTask = "" } }.frame(minHeight: 44) }
                ForEach(store.visible.filter { $0.completedAt == nil || store.plan(day)?.selected.contains($0.id) == true }) { item in
                    let selected = store.plan(day)?.selected.contains(item.id) == true
                    Button {
                        if selected { store.removePriority(item.id, day: day) } else { store.choose(item.id, day: day) }
                    } label: { HStack { Text(item.title); Spacer(); Image(systemName: selected ? "checkmark.circle.fill" : "circle") } }
                }
                Text("No selection means unplanned. Completing every chosen priority qualifies; choose up to three.").font(.footnote).foregroundStyle(.secondary)
            }.personalList().navigationTitle("Choose priorities")
                .toolbar { Button("Done") { dismiss() } }.personalMessage("Priorities", message: $store.message)
        }
    }
}

private struct TodoEditor: View {
    @ObservedObject var store: TodoStore
    @State var item: TodoItem
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("Task", text: $item.title, axis: .vertical)
                TextField("Area", text: $item.area)
                TextField("Note", text: $item.note, axis: .vertical).lineLimit(3...8)
                Toggle("Due date", isOn: Binding(get: { item.due != nil }, set: { item.due = $0 ? Date() : nil; if !$0 { item.hasTime = false } }))
                if item.due != nil {
                    Toggle("At a time", isOn: $item.hasTime)
                    DatePicker("Due", selection: Binding(get: { item.due ?? Date() }, set: { item.due = $0 }), displayedComponents: item.hasTime ? [.date, .hourAndMinute] : [.date])
                }
                Picker("Repeat", selection: $item.repeatRule) {
                    Text("None").tag("none"); Text("Daily").tag("daily"); Text("Weekdays").tag("weekdays")
                    Text("Weekly").tag("weekly"); Text("Every N days").tag("interval")
                }
                if item.repeatRule == "interval" { Stepper("Every \(item.repeatDays) days", value: $item.repeatDays, in: 1...3650) }
                if item.repeatRule == "weekly" {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(Calendar.current.weekdaySymbols[day - 1], isOn: Binding(get: { item.weekdays.contains(day) }, set: { enabled in
                            if enabled { item.weekdays.append(day) } else { item.weekdays.removeAll { $0 == day } }
                        }))
                    }
                }
                if item.repeatRule != "none" { Toggle("Repeat from completion date", isOn: $item.repeatFromCompletion) }
            }.personalList().navigationTitle("Task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    store.message = nil; store.save(item); if store.message == nil { dismiss() }
                }.disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.personalMessage("Task", message: $store.message)
        }
    }
}
