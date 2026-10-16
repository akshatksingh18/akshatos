import SwiftUI

struct PersonalTodayView: View {
    @ObservedObject var study: StudyLogStore
    @ObservedObject var todo: TodoStore
    @ObservedObject var journal: JournalStore
    @ObservedObject var preferences: PersonalPreferences
    var keepGoing: () -> Void
    var openTodo: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var history = false
    @State private var focus = false
    @State private var capture = false
    @State private var topicSheet = false
    @State private var topic = ""
    @State private var chosenDay = ""
    @State private var correcting: StudySegment?
    @State private var planning = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text(study.clock.date(of: study.today)?.formatted(date: typeSize.isAccessibilitySize ? .abbreviated : .complete, time: .omitted) ?? study.today).font(.subheadline).foregroundStyle(.secondary)
                if Calendar.current.component(.hour, from: Date()) < 3 { Text("Still the \(study.today) activity day · changes at 3 AM").font(.caption).foregroundStyle(.secondary) }
                if !study.storageAvailable {
                    ContentUnavailableView { Label("Study data unavailable", systemImage: "exclamationmark.triangle") } actions: { Button("Retry") { study.load() } }
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in timer(at: study.isRunning ? context.date : study.currentDate(), focused: false) }
                }
                if study.storageAvailable {
                    let count = study.days(at: Date()).filter { $0.studied > 0 }.count
                    let milestone = ActivityProgress.milestones.last(where: { $0 <= count }) ?? 0
                    if milestone > preferences.seenMilestone {
                        HStack {
                            Label("\(milestone) days with study recorded", systemImage: "checkmark.seal").foregroundStyle(HubInk.copper)
                            Spacer()
                            Button("Got it") { preferences.seenMilestone = milestone }.frame(minHeight: 44)
                        }.font(.subheadline)
                    }
                }
                priorities
                if let next = todo.nextTimed, let date = next.due {
                    HStack { Image(systemName: "clock"); Text(date.formatted(date: .abbreviated, time: .shortened)); Text(next.title).lineLimit(2) }
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Text("Study this week").font(.title3.weight(.semibold)); Spacer(); Button("History") { history = true }.accessibilityIdentifier("open-study-history") }
                    if study.storageAvailable {
                        StudyWeekGraphic(store: study, anchor: study.today, selected: $chosenDay)
                    } else { Text("History unavailable").foregroundStyle(.secondary) }
                }
            }.padding(22)
        }
        .background(HubInk.background).navigationTitle("Today")
        .sheet(isPresented: $history) { NavigationStack { PersonalProgressView(study: study, todo: todo, journal: journal, preferences: preferences) } }
        .sheet(isPresented: $planning) { PriorityPicker(store: todo, day: todo.today) }
        .fullScreenCover(isPresented: $focus) {
            NavigationStack {
                ScrollView { TimelineView(.periodic(from: .now, by: 1)) { context in timer(at: study.isRunning ? context.date : study.currentDate(), focused: true).padding(22) } }
                    .background(HubInk.background).navigationTitle("Focus").navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Close") { focus = false } }
            }.tint(HubInk.copper)
        }
        .sheet(isPresented: $topicSheet) {
            NavigationStack {
                Form {
                    TextField("Topic · e.g. DSA, SQL, ML", text: $topic)
                    Text("Optional. Saving also tags the current block, if one is running.").font(.footnote).foregroundStyle(.secondary)
                }.personalList().navigationTitle("Study topic")
                    .toolbar { Button("Cancel") { topicSheet = false }; Button("Save") { if study.setTopic(topic) { topicSheet = false } } }
                    .personalMessage("Study topic", message: $study.message)
            }
        }
        .sheet(item: $correcting) { value in StudyCorrectionView(store: study, segment: value) }
        .personalMessage("Study", message: $study.message)
        .personalMessage("To-do", message: $todo.message)
    }
    private func timer(at date: Date, focused: Bool) -> some View {
        VStack(spacing: 10) {
            if !focused {
                HStack {
                    Circle().fill(study.isRunning ? HubInk.copper : HubInk.sage).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(study.isRunning ? "Studying" : typeSize.isAccessibilitySize ? "Paused" : "Ready when you are").font(.subheadline)
                    Spacer()
                    Button { focus = true } label: {
                        Text("Focus").font(.subheadline).frame(minWidth: 44, minHeight: 44)
                    }.accessibilityIdentifier("study-focus")
                }
            }
            if typeSize.isAccessibilitySize { timerControl(at: date) }
            StudyDial(studied: study.studiedToday(at: date), target: study.targetToday(at: date))
                .frame(maxWidth: .infinity).padding(.vertical, 4)
            AdaptiveRow {
                Text("\(StudyTimeDisplay.short(study.studiedToday(at: date))) studied").accessibilityIdentifier("study-studied")
            } trailing: {
                if let block = study.currentBlock(at: date) {
                    Text("Block · \(StudyTimeDisplay.short(block))").accessibilityIdentifier("study-current-block")
                } else if study.studiedToday(at: date) > 0, let end = study.lastPause { Text("Break · \(StudyTimeDisplay.short(max(0, date.timeIntervalSince(end))))") }
            }.font(.caption).foregroundStyle(.secondary)
            if !typeSize.isAccessibilitySize { timerControl(at: date) }
            if study.canUndoEdit { Button("Undo last change") { study.undoEdit() }.frame(minHeight: 44) }
            if capture { ThoughtCaptureField { if todo.park($0) { capture = false; return true }; return false } }
            else { Button { capture = true } label: { Label("Park a thought", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 44) }.foregroundStyle(.secondary) }
            if !focused {
                Button(study.selectedTopic.isEmpty ? "Add a topic" : study.selectedTopic) { topic = study.selectedTopic; topicSheet = true }
                    .font(.caption).frame(minHeight: 44)
                if !study.isRunning && !todo.state.thoughts.isEmpty {
                    Button("\(todo.state.thoughts.count) things waiting in To-do → After study", action: openTodo).font(.caption).frame(minHeight: 44)
                }
                if study.needsRunningReview && date.timeIntervalSince(preferences.lastStudyConfirmation ?? .distantPast) >= 3600 {
                    DisclosureGroup("Check this running block") {
                        Text("A running timer cannot prove uninterrupted study. If you stopped earlier, correct its actual end.").font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button("Still studying", action: keepGoing)
                            Button("Stopped earlier") { if var segment = study.log.running { segment.end = Date(); correcting = segment } }
                        }.buttonStyle(.bordered).padding(.vertical, 8)
                    }
                }
            }
        }.padding(16).background(HubInk.surface, in: RoundedRectangle(cornerRadius: 24))
    }
    private func timerControl(at date: Date) -> some View {
        Button { study.toggle() } label: {
                Label(study.isRunning ? "Pause studying" : study.studiedToday(at: date) > 0 ? "Resume studying" : "Start studying", systemImage: study.isRunning ? "pause.fill" : "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.borderedProminent).tint(HubInk.copper).foregroundStyle(HubInk.background).accessibilityIdentifier("study-toggle")
    }
    private var priorities: some View {
        VStack(alignment: .leading, spacing: 12) {
            let plan = todo.plan(todo.today), values = todo.priorities(todo.today)
            HStack {
                Text("Today’s tasks").font(.title3.weight(.semibold)); Spacer()
                if todo.available && !values.isEmpty { Button("Edit") { planning = true }.frame(minHeight: 44) }
                if todo.available, let plan, !plan.selected.isEmpty { Text("\(plan.completed.count) of \(plan.selected.count)").font(.subheadline).foregroundStyle(.secondary) }
            }
            if !todo.available { Text("Tasks unavailable").foregroundStyle(.secondary) }
            else if values.isEmpty { Button("Choose today’s priorities") { planning = true } }
            else {
                HStack(spacing: 4) { ForEach(values) { item in Capsule().fill(plan?.completed.contains(item.id) == true ? HubInk.sage : HubInk.sage.opacity(0.2)) } }.frame(width: 110, height: 5).accessibilityHidden(true)
                ForEach(values) { item in
                    Button { todo.toggle(item.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.completedAt == nil ? "circle" : "checkmark.circle.fill").font(.title3).foregroundStyle(item.completedAt == nil ? HubInk.copper : HubInk.sage)
                            VStack(alignment: .leading) { Text(item.title).foregroundStyle(item.completedAt == nil ? .primary : .secondary); if item.archivedAt != nil { Text("Archived · choose a replacement").font(.caption).foregroundStyle(.secondary) }; if item.completedAt != nil && plan?.completed.contains(item.id) != true { Text("Completed earlier · choose a replacement").font(.caption).foregroundStyle(.secondary) } }
                            Spacer()
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(item.completedAt != nil || item.archivedAt != nil)
                }
                if todo.undoAvailable { Button("Undo completion") { todo.undo() }.font(.subheadline) }
            }
        }
    }
}

struct StudyWeekGraphic: View {
    @ObservedObject var store: StudyLogStore
    let anchor: String
    @Binding var selected: String
    private func barColor(day: String, total: Double) -> Color {
        let closed = store.days(at: Date()).filter { $0.day < store.today && $0.studied > 0 }
        let best = closed.map(\.studied).max() ?? 0
        if best > 0 && total >= best { return .purple }
        let clock = ActivityDayClock(calendar: store.clock.calendar)
        let prior = (1...7).compactMap { clock.shifted(day, by: -$0) }
        if let first = closed.map(\.day).min(), let start = prior.min(), first <= start {
            let baseline = prior.reduce(0.0) { sum, key in sum + (closed.first { $0.day == key }?.studied ?? 0) } / 7
            if total > baseline && baseline > 0 { return HubInk.sage }
        }
        return HubInk.copper.opacity(day == selected ? 1 : 0.65)
    }
    var body: some View {
        let now = Date(), days = store.clock.week(containing: anchor), blocks = store.log.blocks(now: now, clock: store.clock)
        let totals = days.map { key in blocks.filter { $0.day == key }.reduce(0) { $0 + $1.duration } }
        let scale = max(Double(store.settings.target), totals.max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        let pieces = blocks.filter { $0.day == day }, total = pieces.reduce(0) { $0 + $1.duration }
                        let future = day > store.today
                        Button { selected = day } label: {
                            VStack(spacing: 8) {
                                Text(future ? "—" : String(format: "%.1fh", total / 3600)).font(.caption2).foregroundStyle(.secondary)
                                VStack(spacing: 2) {
                                    Spacer(minLength: 0)
                                    if total > 0 {
                                        VStack(spacing: 2) {
                                            ForEach(pieces) { piece in
                                                RoundedRectangle(cornerRadius: 3).fill(barColor(day: day, total: total))
                                                    .frame(height: max(2, 100 * piece.duration / scale - 2))
                                            }
                                        }.frame(width: 24)
                                    } else { Capsule().fill(HubInk.sage.opacity(0.3)).frame(width: 24, height: 3) }
                                }.frame(height: 100)
                                Text(store.clock.date(of: day)?.formatted(.dateTime.weekday(.abbreviated)) ?? day).font(.caption2)
                            }.frame(minWidth: 44).padding(.vertical, 4)
                                .background(day == selected ? HubInk.copper.opacity(0.05) : .clear, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain).accessibilityLabel("\(day), \(future ? "upcoming day" : StudyTimeDisplay.short(total)), \(pieces.count) blocks")
                            .accessibilityAddTraits(day == selected ? .isSelected : [])
                    }
                }
            }
            let key = selected.isEmpty ? store.today : selected
            let pieces = blocks.filter { $0.day == key }
            Text(key > store.today ? "\(key) · Upcoming day" : "\(key) · \(StudyTimeDisplay.short(pieces.reduce(0) { $0 + $1.duration })) · \(pieces.count) blocks")
                .font(.caption).foregroundStyle(.secondary)
            Text("Copper: study time · green: above usual · purple: personal best").font(.caption2).foregroundStyle(.secondary)
        }.accessibilityIdentifier("study-week")
        .onAppear { if selected.isEmpty { selected = store.today } }
    }
}
