import SwiftUI

struct DailyRoutineSection: View {
    @ObservedObject var store: TodoStore
    @State private var managing = false
    @State private var history = false
    @State private var expanded: Set<RoutinePeriod> = Set(RoutinePeriod.allCases)
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily routine").font(.title3.weight(.semibold))
                    manageButton
                }
            } else {
                HStack { Text("Daily routine").font(.title3.weight(.semibold)); Spacer(); manageButton }
            }
            if !store.available {
                Text("Routine unavailable").foregroundStyle(.secondary)
                Button("Retry loading") { store.load() }
            } else if store.state.routine?.items.isEmpty != false && store.routineToday?.checks.isEmpty != false {
                Text("The things you want to repeat, ready to check off each day.").font(.subheadline).foregroundStyle(.secondary)
                Button("Add your first routine item") { managing = true }.frame(minHeight: 44)
            } else if let day = store.routineToday {
                HStack {
                    Text("\(day.done) of \(day.checks.count) done\(day.skipped > 0 ? " · \(day.skipped) skipped" : "")")
                        .font(.subheadline).foregroundStyle(.secondary).accessibilityIdentifier("routine-count")
                    Spacer()
                    Button("History") { history = true }.font(.subheadline).frame(minWidth: 44, minHeight: 44)
                }
                if day.checks.isEmpty { Text("Nothing scheduled today.").foregroundStyle(.secondary) }
                else {
                    ProgressView(value: Double(day.done), total: Double(day.checks.count)).tint(HubInk.sage)
                        .accessibilityLabel("Daily routine").accessibilityValue("\(day.done) of \(day.checks.count) completed")
                    ForEach(RoutinePeriod.allCases) { period in
                        let checks = day.checks.filter { $0.period == period }
                        if !checks.isEmpty {
                            DisclosureGroup(isExpanded: Binding(get: { expanded.contains(period) }, set: { if $0 { expanded.insert(period) } else { expanded.remove(period) } })) {
                                ForEach(checks) { check in checkRow(check, day: day.day) }
                            } label: {
                                HStack {
                                    Label(period.title, systemImage: period.symbol)
                                    Spacer()
                                    Text("\(checks.filter { $0.status == .done }.count)/\(checks.count)")
                                        .foregroundStyle(.secondary)
                                }.font(.subheadline).frame(minHeight: 44)
                            }
                        }
                    }
                }
            } else {
                Text("Today's checklist hasn't been saved yet.").foregroundStyle(.secondary)
                Button("Retry loading") { store.load() }
            }
        }
        .sheet(isPresented: $managing) { RoutineManager(store: store) }
        .sheet(isPresented: $history) { RoutineHistory(store: store) }
    }
    private var manageButton: some View {
        Button("Manage") { managing = true }.fixedSize().frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("routine-manage")
    }
    private func checkRow(_ check: RoutineCheck, day: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                store.recordRoutine(check.id, status: check.status == .done ? .pending : .done, day: day)
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: check.status == .done ? "checkmark.circle.fill" : check.status == .skipped ? "minus.circle" : "circle")
                        .font(.title3).foregroundStyle(check.status == .done ? HubInk.sage : HubInk.copper)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(check.title).foregroundStyle(check.status == .pending ? .primary : .secondary)
                            .multilineTextAlignment(.leading)
                        if let minute = check.targetMinute { Text(routineTime(minute)).font(.caption).foregroundStyle(.secondary) }
                        if check.status == .skipped { Text("Skipped").font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 10).frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityLabel("\(check.status == .done ? "Uncheck" : "Complete") \(check.title)")
                .accessibilityValue(check.status.rawValue)
                .accessibilityIdentifier("routine-check-" + check.title)
            Menu {
                if check.status != .skipped { Button("Skip today") { store.recordRoutine(check.id, status: .skipped, day: day) } }
                if check.status != .pending { Button("Mark not done") { store.recordRoutine(check.id, status: .pending, day: day) } }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("Options for \(check.title)")
        }
    }
}

struct RoutineManager: View {
    @ObservedObject var store: TodoStore
    @Environment(\.dismiss) private var dismiss
    @State private var editing: RoutineItem?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Add routine item", systemImage: "plus") { editing = RoutineItem(title: "") }
                        .disabled(!store.available).accessibilityIdentifier("routine-add")
                }
                Section("Your items") {
                    ForEach(store.state.routine?.items ?? []) { item in
                        Button { editing = item } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).foregroundStyle(.primary)
                                Text("\(item.period.title)\(item.targetMinute.map { " · " + routineTime($0) } ?? "")\(item.paused ? " · Paused" : "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4).frame(minHeight: 44, alignment: .leading)
                        }
                        .swipeActions { Button("Remove", role: .destructive) { store.removeRoutine(item.id) } }
                    }.onMove { store.moveRoutines(from: $0, to: $1) }
                }
                Section {
                    NavigationLink("Routine history") { RoutineHistoryContent(store: store) }
                    DisclosureGroup("How routines work") {
                        Text("Your routine repeats on its selected days. Check it off on Today; a fresh day starts at 3 AM. Times are targets, not alarms.")
                        Text("Remove or pause an item to stop future appearances. Closed days keep their saved checklist. Editing today's unfinished items changes today's list; completed and skipped entries keep their original wording.")
                    }.font(.footnote).foregroundStyle(.secondary)
                }
            }.personalList().navigationTitle("Daily routine")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .topBarTrailing) { EditButton() } }
                .sheet(item: $editing) { RoutineEditor(store: store, item: $0) }
                .personalMessage("Daily routine", message: $store.message)
        }
    }
}

struct RoutineEditor: View {
    @ObservedObject var store: TodoStore
    @State var item: RoutineItem
    @Environment(\.dismiss) private var dismiss
    private var time: Binding<Date> {
        Binding(get: { Calendar.current.date(bySettingHour: (item.targetMinute ?? 480) / 60, minute: (item.targetMinute ?? 480) % 60, second: 0, of: Date()) ?? Date() },
                set: { item.targetMinute = Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0) })
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Routine item") {
                    TextField("What do you want to do?", text: $item.title, axis: .vertical).accessibilityIdentifier("routine-title")
                    Picker("Part of day", selection: $item.period) { ForEach(RoutinePeriod.allCases) { Text($0.title).tag($0) } }
                    Toggle("Target time", isOn: Binding(get: { item.targetMinute != nil }, set: { item.targetMinute = $0 ? 480 : nil }))
                    if item.targetMinute != nil { DatePicker("Aim for", selection: time, displayedComponents: .hourAndMinute) }
                }
                Section("Repeat on") {
                    ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                        Toggle(Calendar.current.weekdaySymbols[weekday - 1], isOn: Binding(get: { item.weekdays.contains(weekday) }, set: { on in
                            item.weekdays.removeAll { $0 == weekday }; if on { item.weekdays.append(weekday) }
                        }))
                    }
                }
                Section {
                    Toggle("Pause this item", isOn: $item.paused)
                    Text("Checking it off records your confirmation. It does not measure wake-up time, reading or study automatically. No notifications are added.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.personalList().navigationTitle("Routine item").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.saveRoutine(item) { dismiss() }
                    }.disabled(item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || item.weekdays.isEmpty || !store.available).accessibilityIdentifier("routine-save") }
                }.personalMessage("Routine item", message: $store.message)
        }
    }
}

private struct RoutineHistory: View {
    @ObservedObject var store: TodoStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { RoutineHistoryContent(store: store).toolbar { Button("Done") { dismiss() } } }
    }
}
struct RoutineHistoryContent: View {
    @ObservedObject var store: TodoStore
    var body: some View {
        List {
            Section {
                Text("Past seven days").font(.footnote).foregroundStyle(.secondary)
            }
            if !store.available { Text("Routine history unavailable") }
            else {
                ForEach((0..<7).compactMap { store.clock.shifted(store.today, by: -$0) }, id: \.self) { key in
                    Section(store.clock.date(key)?.formatted(date: .abbreviated, time: .omitted) ?? key) {
                        if let day = store.state.routine?.days.first(where: { $0.day == key }) {
                            Text("\(day.done) of \(day.checks.count) done · \(day.skipped) skipped").font(.subheadline)
                            ForEach(day.checks) { check in
                                HStack(alignment: .top) {
                                    Image(systemName: check.status == .done ? "checkmark.circle.fill" : check.status == .skipped ? "minus.circle" : "circle")
                                        .foregroundStyle(check.status == .done ? HubInk.sage : .secondary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(check.title)
                                        if let recorded = check.recordedAt {
                                            Text("\(check.status == .done ? "Checked" : "Skipped") at \(routineRecordedTime(recorded, zone: day.zone))")
                                                .font(.caption).foregroundStyle(.secondary)
                                        } else { Text("Not checked off").font(.caption).foregroundStyle(.secondary) }
                                    }
                                }.accessibilityElement(children: .combine)
                            }
                            if day.checks.isEmpty { Text("Nothing scheduled").foregroundStyle(.secondary) }
                            if day.zone != TimeZone.current.identifier {
                                Text("Times use \(TimeZone(identifier: day.zone)?.localizedName(for: .generic, locale: .current) ?? day.zone)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else { Text("Not recorded").foregroundStyle(.secondary) }
                    }
                }
            }
            Section {
                DisclosureGroup("About this history") {
                    Text("Skipped is separate from done. Unrecorded days have no saved checklist; they are not assumed missed. Check-off times use the time zone saved with that activity day.")
                }.font(.footnote).foregroundStyle(.secondary)
            }
        }.personalList().navigationTitle("Routine history").navigationBarTitleDisplayMode(.inline)
    }
}

private func routineTime(_ minute: Int) -> String {
    let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    return date.formatted(date: .omitted, time: .shortened)
}

private func routineRecordedTime(_ date: Date, zone: String) -> String {
    let formatter = DateFormatter(); formatter.timeStyle = .short
    formatter.timeZone = TimeZone(identifier: zone)
    return formatter.string(from: date)
}
