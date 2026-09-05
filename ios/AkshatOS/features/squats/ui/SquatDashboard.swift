import SwiftUI
import UniformTypeIdentifiers

struct SquatDashboard: View {
    @EnvironmentObject private var store: SquatStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false
    @State private var showEnd = false
    @State private var showRestart = false
    @State private var showDeleteHistory = false
    @State private var showRestore = false
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportDocument: SquatsBackupDocument?
    @State private var pendingRestore: SquatsBackup?
    @State private var showHomeSetup = false
    @State private var showDisableHome = false
    @State private var showOutsideStart = false
    @ScaledMetric(relativeTo: .largeTitle) private var countdownSize: CGFloat = 48
    @ScaledMetric(relativeTo: .largeTitle) private var todayCountSize: CGFloat = 56
    @ScaledMetric(relativeTo: .largeTitle) private var summaryCountSize: CGFloat = 64

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
                if store.pendingActionCount > 0 {
                    Surface {
                        Label("\(store.pendingActionCount) notification actions waiting to save", systemImage: "tray.and.arrow.down")
                        Text("Unlock your phone and retry. Queued actions are kept until local history can be updated.")
                            .font(.caption).foregroundStyle(Palette.muted)
                        Button("Retry saved actions") { Task { await store.refresh() } }
                            .disabled(store.busy)
                    }
                }
                Surface {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(store.todayCount)").font(.system(size: todayCountSize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("sets today").foregroundStyle(Palette.muted)
                        Spacer()
                        Image(systemName: "figure.strengthtraining.traditional").font(.title).foregroundStyle(Palette.lime)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(store.todayCount) sets today")
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
                Text(store.homeEnabled ? "Home auto-pause: \(store.homeHealth)." : "Home auto-pause is optional and currently off.")
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
        .alert("Squats needs attention", isPresented: Binding(
            get: { store.message != nil }, set: { if !$0 { store.message = nil; store.messageRoute = nil } })) {
                if store.messageRoute == .notifications {
                    Button("Open Notification Settings") { openNotificationSettings(); store.message = nil; store.messageRoute = nil }
                } else if store.messageRoute == .location {
                    Button("Open Location Settings") { openLocationSettings(); store.message = nil; store.messageRoute = nil }
                }
                Button("OK") { store.message = nil; store.messageRoute = nil }
            } message: { Text(store.message ?? "") }
        .alert("Squats", isPresented: Binding(
            get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
                Button("OK") { store.notice = nil }
            } message: { Text(store.notice ?? "") }
        .confirmationDialog("End your day and stop reminders?", isPresented: $showEnd, titleVisibility: .visible) {
            Button("End my day", role: .destructive) { Task { await store.end() } }
        }
        .confirmationDialog("Start another session today? Your earlier sets still count.",
                            isPresented: $showRestart, titleVisibility: .visible) {
            Button("Start another session") { startRequested() }
        }
        .confirmationDialog("You are outside Home", isPresented: $showOutsideStart,
                            titleVisibility: .visible) {
            Button("Start paused until I arrive Home") { Task { await store.start(pausedForHome: true) } }
            Button("Run reminders anyway") { Task { await store.start() } }
        } message: {
            Text("Choose whether this day should wait for your return or run while you are away.")
        }
    }

    private var hero: some View {
        Surface {
            Group {
                HStack {
                    Label(store.operational, systemImage: stateIcon)
                        .font(.headline).foregroundStyle(Palette.lime)
                    Spacer()
                    if store.busy { ProgressView().tint(Palette.lime) }
                }
                if let date = store.nextReminder {
                    VStack(alignment: .leading, spacing: 5) {
                        TimelineView(.periodic(from: .now, by: reduceMotion ? 30 : 1)) { context in
                            let interval = TimeInterval((store.active?.interval ?? 45) * 60)
                            let elapsed = max(0, context.date.timeIntervalSince(date))
                            let next = date > context.date ? date : date.addingTimeInterval((floor(elapsed / interval) + 1) * interval)
                            let seconds = max(0, Int(ceil(next.timeIntervalSince(context.date))))
                            Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                                .font(.system(size: countdownSize, weight: .medium, design: .rounded)).monospacedDigit()
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
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(heroAccessibilityLabel)
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
                    if store.today.isEmpty { startRequested() }
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
        case "Reminder needs repair": return "The saved schedule is missing or needs the current action buttons. Re-arm it to continue."
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
                    .accessibilityElement(children: .combine)
                ProgressView(value: Double(min(store.todayCount, goal)), total: Double(goal)).tint(Palette.lime)
                    .accessibilityLabel("Progress toward today's goal")
                    .accessibilityValue("\(min(store.todayCount, goal)) of \(goal) sets")
                if store.todayCount < goal {
                    Text("Today is at risk; your existing streak remains intact until the local day ends.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
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
                        .foregroundStyle(Palette.lime).accessibilityHidden(true)
                    Text(eventTitle(event.kind)).font(.subheadline)
                    Spacer()
                    Text(event.date, style: .time).font(.caption).foregroundStyle(Palette.muted)
                }.padding(.vertical, 5)
                    .accessibilityElement(children: .combine)
            }
            Text("History").font(.system(.title3, design: .rounded, weight: .bold)).padding(.top, 8)
            if store.daySummaries.isEmpty {
                Text("Completed and active days will appear here.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            ForEach(store.daySummaries) { day in
                Button { store.summary = day } label: {
                    HStack {
                        Label(day.started.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                              systemImage: "clock.arrow.circlepath")
                        Spacer()
                        Text("\(day.completedSets) sets")
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }.font(.subheadline).padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
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
                }
                Section("Notifications") {
                    Label(notificationStatusText, systemImage: notificationStatusIcon)
                        .accessibilityIdentifier("notification-permission-status")
                    switch store.notificationAuthorization {
                    case .denied:
                        Text("Notifications were turned off. Reminders cannot be delivered until you allow them again in iOS Settings.")
                            .font(.caption).foregroundStyle(.secondary)
                        settingsLink
                    case .notDetermined:
                        Text("You'll be asked to allow notifications the first time you tap Start my day.")
                            .font(.caption).foregroundStyle(.secondary)
                    case .provisional:
                        Text("Notifications currently deliver quietly, without a banner or sound. Change this in iOS Settings for the usual alert.")
                            .font(.caption).foregroundStyle(.secondary)
                        settingsLink
                    case .authorized, .ephemeral:
                        EmptyView()
                    }
                    Text("Focus modes can silence or defer reminders, Scheduled Summary can bundle them, and per-app sound/banner settings can make an accepted request appear not to work. AkshatOS can only show what iOS reports; it cannot override these choices.")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("notification-permission-caveats")
                }
                Section("Data management") {
                    Button {
                        do {
                            exportDocument = SquatsBackupDocument(data: try store.makeBackupData())
                            showExporter = true
                        } catch { store.message = error.localizedDescription; store.messageRoute = nil }
                    } label: { Label("Export Squats backup", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("export-squats-backup")
                    Button { showImporter = true } label: {
                        Label("Restore Squats backup", systemImage: "square.and.arrow.down")
                    }.accessibilityIdentifier("restore-squats-backup")
                    Button("Delete completed history", role: .destructive) { showDeleteHistory = true }
                        .accessibilityIdentifier("delete-squats-history")
                    Text("Backups are versioned JSON files stored wherever you choose in Files. Restore validates the entire file before replacing local Squats data.")
                        .font(.caption).foregroundStyle(.secondary)
                }.disabled(store.busy || !store.storageAvailable)
                Section("Home auto-pause") {
                    Label(store.homeHealth, systemImage: store.homeEnabled ? "house.fill" : "house")
                        .accessibilityIdentifier("home-automation-status")
                    if store.homeEnabled {
                        Text("AkshatOS stores one circular Home boundary on this phone. Leaving pauses a running day; arriving resumes only a same-day pause caused by Home departure.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Update Home from my current location") {
                            Task {
                                await store.editHome()
                                showHomeSetup = store.homeDraft != nil
                            }
                        }
                        Button("Disable and delete Home", role: .destructive) { showDisableHome = true }
                    } else {
                        Text("Optional. Setup asks for location in two stages and never saves a movement trail.")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Use my current location as Home") {
                            Task {
                                await store.chooseCurrentLocationAsHome()
                                showHomeSetup = store.homeDraft != nil
                            }
                        }.accessibilityIdentifier("set-home-location")
                    }
                    if store.homeEnabled {
                        switch store.homeAuthorization {
                        case .denied:
                            Text("Location access was denied. Enable it in iOS Settings to use Home auto-pause.")
                                .font(.caption).foregroundStyle(.secondary)
                            settingsLinkLocation
                        case .restricted:
                            Text("Location access is restricted by parental controls or a management profile on this device and can't be changed from within AkshatOS.")
                                .font(.caption).foregroundStyle(.secondary)
                        case .whenInUse:
                            Text("Always access is needed so Home auto-pause can work while AkshatOS is closed.")
                                .font(.caption).foregroundStyle(.secondary)
                            settingsLinkLocation
                        case .notDetermined, .always:
                            EmptyView()
                        }
                    }
                }.disabled(store.busy)
                Section("Coming later") {
                    Label("Shortcuts", systemImage: "app.badge")
                }.foregroundStyle(.secondary)
                Section("Notification actions") {
                    Text("Done logs one set. Pause stops reminders until you resume. Expand a notification for Remind me in 10 min; it keeps your regular cadence.")
                        .accessibilityIdentifier("notification-actions-help")
                }
            }.navigationTitle("Squat settings")
                .toolbar { Button("Done") { showSettings = false } }
        }.tint(Palette.lime)
            .sheet(isPresented: $showHomeSetup) { HomeSetupView() }
            .confirmationDialog("Restore this Squats backup?", isPresented: $showRestore,
                                titleVisibility: .visible) {
                Button("Replace current Squats data", role: .destructive) {
                    if let pendingRestore { Task { await store.restore(pendingRestore) } }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("This replaces current Squats history and settings with \(pendingRestore?.sessions.count ?? 0) saved sessions and stops the current reminder schedule.")
            }
            .confirmationDialog("Delete completed Squats history?", isPresented: $showDeleteHistory,
                                titleVisibility: .visible) {
                Button("Delete completed history", role: .destructive) {
                    Task { await store.deleteHistory() }
                }
            } message: {
                Text("This keeps an active day and your settings. Export a backup first if you may need the completed history later.")
            }
            .confirmationDialog("Disable Home auto-pause and delete its boundary?",
                                isPresented: $showDisableHome, titleVisibility: .visible) {
                Button("Disable and delete Home", role: .destructive) {
                    Task { await store.disableHome() }
                }
            }
            .fileExporter(isPresented: $showExporter, document: exportDocument,
                          contentType: .json, defaultFilename: "squats-backup") { result in
                if case .failure(let error) = result { store.message = error.localizedDescription; store.messageRoute = nil }
                exportDocument = nil
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    pendingRestore = try store.prepareRestore(Data(contentsOf: url, options: .mappedIfSafe))
                    showRestore = true
                } catch { store.message = error.localizedDescription; store.messageRoute = nil }
            }
            .alert("Squats needs attention", isPresented: Binding(
                get: { store.message != nil }, set: { if !$0 { store.message = nil; store.messageRoute = nil } })) {
                    if store.messageRoute == .notifications {
                        Button("Open Notification Settings") { openNotificationSettings(); store.message = nil; store.messageRoute = nil }
                    } else if store.messageRoute == .location {
                        Button("Open Location Settings") { openLocationSettings(); store.message = nil; store.messageRoute = nil }
                    }
                    Button("OK") { store.message = nil; store.messageRoute = nil }
                } message: { Text(store.message ?? "") }
            .alert("Squats", isPresented: Binding(
                get: { store.notice != nil }, set: { if !$0 { store.notice = nil } })) {
                    Button("OK") { store.notice = nil }
                } message: { Text(store.notice ?? "") }
    }

    private var settingsLink: some View {
        Button("Open iOS notification settings") { openNotificationSettings() }
    }

    private var settingsLinkLocation: some View {
        Button("Open iOS location settings") { openLocationSettings() }
    }

    private func openNotificationSettings() {
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func openLocationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var notificationStatusText: String {
        switch store.notificationAuthorization {
        case .authorized: return "Notifications allowed"
        case .provisional: return "Notifications allowed quietly"
        case .ephemeral: return "Notifications allowed temporarily"
        case .denied: return "Notifications turned off"
        case .notDetermined: return "Notifications not yet requested"
        }
    }

    private var notificationStatusIcon: String {
        switch store.notificationAuthorization {
        case .authorized, .provisional, .ephemeral: return "bell.badge"
        case .denied: return "bell.slash"
        case .notDetermined: return "bell"
        }
    }

    private var stateIcon: String {
        switch store.operational {
        case "Running": return "bell.badge"
        case "Paused": return "pause.circle"
        case "Day complete": return "checkmark.seal"
        case "Notifications blocked": return "bell.slash"
        case "Reminder needs repair": return "exclamationmark.triangle"
        case "Storage unavailable": return "externaldrive.badge.exclamationmark"
        default: return "sun.max"
        }
    }

    private var heroAccessibilityLabel: String {
        var parts = [store.operational]
        if let date = store.nextReminder {
            parts.append("Next reminder around \(date.formatted(date: .omitted, time: .shortened))")
        } else {
            parts.append(heroDescription)
        }
        if let snooze = store.snoozeReminder {
            parts.append("Extra nudge around \(snooze.formatted(date: .omitted, time: .shortened))")
        }
        if store.busy { parts.append("Working") }
        return parts.joined(separator: ". ")
    }

    private func startRequested() {
        if store.shouldOfferOutsideStart { showOutsideStart = true }
        else { Task { await store.start() } }
    }

    private func summary(_ day: SquatDaySummary) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("You made time\nto move.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Surface {
                        Text("\(day.completedSets)").font(.system(size: summaryCountSize, weight: .bold, design: .rounded)).foregroundStyle(Palette.lime)
                        Text("completed sets this day").foregroundStyle(Palette.muted)
                        Text(day.started.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                            .font(.headline)
                        Text(goalDescription(day)).foregroundStyle(Palette.muted)
                    }
                    Surface {
                        Label("Time in your day", systemImage: "clock").font(.headline)
                        Text("Started \(day.started.formatted(date: .omitted, time: .shortened))")
                        if let end = day.ended { Text("Ended \(end.formatted(date: .omitted, time: .shortened))") }
                        else { Text("Day still open") }
                        Text("Active \(duration(day.activeDuration)) · Paused \(duration(day.pausedDuration))")
                        Text("\(day.sessions.count) session\(day.sessions.count == 1 ? "" : "s") · interval \(day.intervals.map(String.init).joined(separator: ", ")) min")
                        Text("\(day.pauseSegments.count) pauses · \(day.snoozeTimes.count) snoozes")
                    }
                    if !day.pauseSegments.isEmpty {
                        Surface {
                            Label("Pause segments", systemImage: "pause.circle").font(.headline)
                            ForEach(day.pauseSegments) { pause in
                                HStack {
                                    Text("\(pause.started.formatted(date: .omitted, time: .shortened))–\(pause.ended.formatted(date: .omitted, time: .shortened))")
                                    Spacer()
                                    Text(duration(pause.duration)).foregroundStyle(Palette.muted)
                                }.font(.subheadline)
                            }
                        }
                    }
                    Surface {
                        Label("Daily timeline", systemImage: "list.bullet").font(.headline)
                        if day.events.isEmpty { Text("No activity was logged.").foregroundStyle(Palette.muted) }
                        ForEach(day.events) { event in
                            HStack {
                                Text(eventTitle(event.kind))
                                Spacer()
                                Text(event.date, style: .time).foregroundStyle(Palette.muted)
                            }.font(.subheadline)
                        }
                    }
                }.padding(24)
            }.background(Palette.background).navigationTitle("Daily overview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { store.summary = nil } }
        }.tint(Palette.lime)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(.title, design: .rounded, weight: .bold))
            Text(label).font(.caption).foregroundStyle(Palette.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private func eventTitle(_ kind: SquatEvent.Kind) -> String {
        switch kind {
        case .done: return "Squat set completed"
        case .pause: return "Reminders paused"
        case .resume: return "Reminders resumed"
        case .snooze: return "Extra nudge requested"
        }
    }

    private func duration(_ value: TimeInterval) -> String {
        let minutes = max(0, Int(value) / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func goalDescription(_ day: SquatDaySummary) -> String {
        switch day.goalStatus {
        case .notSet: return "No goal was set for this day."
        case .reached: return "Goal reached: \(day.completedSets)/\(day.goal!) sets."
        case .atRisk: return "Goal in progress: \(day.completedSets)/\(day.goal!) sets."
        case .missed: return "Goal not reached: \(day.completedSets)/\(day.goal!) sets."
        }
    }
}

struct SquatsBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw SquatsBackupError.invalidFile }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
