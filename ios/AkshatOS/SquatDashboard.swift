import SwiftUI

struct SquatDashboard: View {
    @EnvironmentObject private var store: SquatStore
    @State private var showSettings = false
    @State private var showEnd = false
    @State private var showRestart = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    Text("A little stronger,\none break at a time.")
                        .font(.system(.title, design: .rounded, weight: .bold))
                }
                hero
                Surface {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(store.todayCount)").font(.system(size: 56, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("sets today").foregroundStyle(Palette.muted)
                        Spacer()
                        Image(systemName: "figure.strengthtraining.traditional").font(.title).foregroundStyle(Palette.lime)
                    }
                    Button { Task { await store.done() } } label: {
                        Label("Done +1", systemImage: "checkmark")
                    }.buttonStyle(ActionStyle(primary: true))
                        .disabled(store.active == nil || store.staleDay || store.busy || !store.storageAvailable)
                        .accessibilityIdentifier("log-set")
                    if let active = store.active, active.count > 0, !store.staleDay {
                        Button("Undo last set") { Task { await store.undo() } }
                            .font(.footnote).frame(maxWidth: .infinity).disabled(store.busy)
                    } else {
                        Text("Count a set only after you've done it.")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                }
                goalCard
                timeline
                Text("Home auto-pause and notification buttons are coming next. For now, use this dashboard to pause, log, or snooze.")
                    .font(.footnote).foregroundStyle(Palette.muted)
                Text("AkshatOS · Preview 0.2.0")
                    .font(.caption2).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
            }.padding(22)
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Squat Reminder").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Squat settings")
            }
        }
        .sheet(isPresented: $showSettings) { settings }
        .sheet(item: $store.summary) { session in summary(session) }
        .alert("Could not complete action", isPresented: Binding(
            get: { store.message != nil }, set: { if !$0 { store.message = nil } })) {
                Button("OK") { store.message = nil }
            } message: { Text(store.message ?? "") }
        .confirmationDialog("End your day and stop reminders?", isPresented: $showEnd, titleVisibility: .visible) {
            Button("End my day", role: .destructive) { Task { await store.end() } }
        }
        .confirmationDialog("Start another session today? Your earlier sets still count.",
                            isPresented: $showRestart, titleVisibility: .visible) {
            Button("Start another session") { Task { await store.start() } }
        }
    }

    private var hero: some View {
        Surface {
            HStack {
                Label(store.operational, systemImage: store.operational == "Running" ? "bell.badge" : "sun.max")
                    .font(.headline).foregroundStyle(Palette.lime)
                Spacer()
                if store.busy { ProgressView().tint(Palette.lime) }
            }
            if let date = store.nextReminder {
                VStack(alignment: .leading, spacing: 5) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let interval = TimeInterval((store.active?.interval ?? 45) * 60)
                        let elapsed = max(0, context.date.timeIntervalSince(date))
                        let next = date > context.date ? date : date.addingTimeInterval((floor(elapsed / interval) + 1) * interval)
                        let seconds = max(0, Int(ceil(next.timeIntervalSince(context.date))))
                        Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                            .font(.system(size: 48, weight: .medium, design: .rounded)).monospacedDigit()
                    }
                    Text("until the next scheduled reminder")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if let snooze = store.snoozeReminder {
                    Text("Extra nudge at \(snooze.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(Palette.lime)
                }
            } else {
                Text(heroDescription).font(.body).foregroundStyle(Palette.muted)
            }
            if let active = store.active {
                if !store.staleDay {
                    Button {
                        Task {
                            if store.operational == "Running" { await store.pause() }
                            else { await store.resume() }
                        }
                    } label: {
                        Text(store.operational == "Running" ? "Pause reminders" :
                             (active.state == .paused ? "Resume reminders" : "Repair reminders"))
                    }.buttonStyle(ActionStyle(primary: true)).disabled(store.busy || !store.storageAvailable)
                    if store.operational == "Running" {
                        Button("Remind me in 10 min") { Task { await store.snooze() } }
                            .buttonStyle(ActionStyle()).disabled(store.busy)
                    }
                    if store.operational == "Notifications blocked" { settingsLink }
                    if active.state == .running && store.operational != "Running" {
                        Button("Pause until I resume") { Task { await store.pause() } }
                            .buttonStyle(ActionStyle()).disabled(store.busy)
                    }
                }
                Button("End my day") { showEnd = true }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity).disabled(store.busy || !store.storageAvailable)
            } else {
                Button {
                    if store.today.isEmpty { Task { await store.start() } }
                    else { showRestart = true }
                } label: { Text(store.today.isEmpty ? "Start my day" : "Start another session") }
                    .buttonStyle(ActionStyle(primary: true)).disabled(store.busy || !store.storageAvailable)
            }
            Text("Every \(store.active?.interval ?? store.interval) min · Focus and iOS settings may silence alerts.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
    }

    private var heroDescription: String {
        if store.staleDay { return "A session from \(store.active!.day) is still open. End it before starting today; reminders have been stopped." }
        switch store.operational {
        case "Paused": return "Take your time. Your day stays open until you're ready to return."
        case "Day complete": return "Good work showing up. Your sets are saved for today."
        case "Notifications blocked": return "Enable notifications in iOS Settings to receive reminders."
        case "Reminder needs repair": return "The saved schedule is missing or changed. Re-arm it to continue."
        case "Storage unavailable": return "Local storage needs attention. Keep the app installed to preserve your data."
        default: return "Start when you're ready. Your first reminder comes one full interval later."
        }
    }

    private var goalCard: some View {
        Surface {
            Label("Keep showing up", systemImage: "flame").font(.headline)
            if let goal = store.todayGoal {
                HStack {
                    Text(store.todayCount >= goal ? "Today's goal reached" : "\(max(0, goal - store.todayCount)) more sets to your goal")
                    Spacer()
                    Text("\(store.todayCount)/\(goal)").monospacedDigit()
                }.font(.subheadline).foregroundStyle(Palette.muted)
                ProgressView(value: Double(min(store.todayCount, goal)), total: Double(goal)).tint(Palette.lime)
            } else {
                Text("Choose a daily set goal in Settings to begin your streak. No target is chosen for you.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 32) {
                stat("\(store.streaks.current)", "day streak")
                stat("\(store.streaks.best)", "personal best")
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your day, so far").font(.system(.title3, design: .rounded, weight: .bold))
            let events = store.today.flatMap(\.events).sorted { $0.date > $1.date }
            if events.isEmpty {
                Text("A fresh page. Your movement breaks will appear here.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            ForEach(Array(events.prefix(12))) { event in
                HStack(spacing: 12) {
                    Image(systemName: event.kind == .done ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(Palette.lime)
                    Text(eventTitle(event.kind)).font(.subheadline)
                    Spacer()
                    Text(event.date, style: .time).font(.caption).foregroundStyle(Palette.muted)
                }.padding(.vertical, 5)
            }
            ForEach(store.sessions.filter { !$0.isActive }.prefix(7)) { session in
                Button { store.summary = session } label: {
                    HStack {
                        Label(session.day, systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("\(session.count) sets")
                        Image(systemName: "chevron.right")
                    }.font(.subheadline).padding(.vertical, 10)
                }
            }
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Your rhythm") {
                    Stepper("Every \(store.interval) minutes", value: $store.interval, in: 1...180)
                    Stepper(store.goal == 0 ? "Daily goal: not set" : "Daily goal: \(store.goal) sets",
                            value: $store.goal, in: 0...100)
                }.disabled(store.active != nil || store.busy)
                Section {
                    Text("Settings are locked during an active session. Each day's first session fixes that day's goal; changes apply to the next new day. A goal of zero leaves streak tracking off.")
                    settingsLink
                }
                Section("Coming later") {
                    Label("Home auto-pause", systemImage: "house")
                    Label("Notification action buttons", systemImage: "bell")
                    Label("Shortcuts & data export", systemImage: "square.and.arrow.up")
                }.foregroundStyle(.secondary)
            }.navigationTitle("Squat settings")
                .toolbar { Button("Done") { showSettings = false } }
        }.tint(Palette.lime)
    }

    private var settingsLink: some View {
        Button("Open iOS notification settings") {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func summary(_ session: SquatSession) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("You made time\nto move.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Surface {
                        Text("\(session.count)").font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(Palette.lime)
                        Text("completed sets this session").foregroundStyle(Palette.muted)
                        Text(session.day).font(.headline)
                        Text("Started \(session.started.formatted(date: .abbreviated, time: .shortened))")
                        if let end = session.ended { Text("Ended \(end.formatted(date: .abbreviated, time: .shortened))") }
                        Text("\(session.interval)-minute interval")
                        Text("\(session.events.filter { $0.kind == .pause }.count) pauses · \(session.events.filter { $0.kind == .snooze }.count) snoozes")
                        Text("Your daily goal uses all sessions on the same date.").font(.caption).foregroundStyle(Palette.muted)
                    }
                }.padding(24)
            }.background(Palette.background).navigationTitle("Session overview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { store.summary = nil } }
        }.tint(Palette.lime)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(.title, design: .rounded, weight: .bold))
            Text(label).font(.caption).foregroundStyle(Palette.muted)
        }
    }

    private func eventTitle(_ kind: SquatEvent.Kind) -> String {
        switch kind {
        case .done: return "Squat set completed"
        case .pause: return "Reminders paused"
        case .resume: return "Reminders resumed"
        case .snooze: return "Extra nudge requested"
        }
    }
}
