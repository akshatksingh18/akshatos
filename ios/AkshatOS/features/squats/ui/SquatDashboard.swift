import SwiftUI
import UniformTypeIdentifiers

struct SquatDashboard: View {
    @EnvironmentObject private var store: SquatStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @ScaledMetric(relativeTo: .largeTitle) private var summaryCountSize: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var reminderAreaMinHeight: CGFloat = 76

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    QuestBadge(text: "Daily power-up", icon: "bolt.fill", accent: Palette.coral)
                    Text("Drop. Press.\nLevel up.")
                        .font(.system(.largeTitle, design: .rounded, weight: .black))
                    Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                        .font(.subheadline).foregroundStyle(Palette.muted)
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
                AccentSurface(accent: Palette.coral) {
                    AdaptiveRow(spacing: 18) {
                        ProgressOrbit(progress: powerProgress, value: "\(store.todayCount)", caption: "SETS",
                                      accent: Palette.coral, systemImage: "bolt.fill")
                    } trailing: {
                        VStack(alignment: .leading, spacing: 7) {
                            QuestBadge(text: powerStatus, icon: powerStatusIcon, accent: Palette.coral)
                            Text("Pushup power")
                                .font(.system(.title2, design: .rounded, weight: .black))
                            Text("Every finished set charges today's power bar.")
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(store.todayCount) pushup sets today. \(powerStatus).")
                    Button { Task { await store.done() } } label: {
                        Label("Set crushed  +1", systemImage: "bolt.fill")
                    }.buttonStyle(ActionStyle(primary: true))
                        .disabled(store.active == nil || store.staleDay || store.busy || !store.storageAvailable)
                        .accessibilityIdentifier("log-set")
                    ZStack {
                        Text("Tap only after the pushup set is done — honor system, hero rules.")
                            .font(.caption).foregroundStyle(Palette.muted)
                            .opacity(canUndo ? 0 : 1)
                            .accessibilityHidden(canUndo)
                        Button("Undo last set") { Task { await store.undo() } }
                            .font(.footnote).frame(maxWidth: .infinity).disabled(store.busy)
                            .opacity(canUndo ? 1 : 0)
                            .allowsHitTesting(canUndo)
                            .accessibilityHidden(!canUndo)
                    }
                    .frame(maxWidth: .infinity)
                }
                goalCard
                timeline
                HStack(spacing: 6) {
                    Image(systemName: homeHealthIcon)
                        .font(.footnote)
                        .foregroundStyle(homeHealthIsDegraded ? Color.orange : Palette.muted)
                        .accessibilityHidden(true)
                    Text(store.homeEnabled ? "Home auto-pause: \(store.homeHealth)." : "Home auto-pause is optional and currently off.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                .accessibilityElement(children: .combine)
                Text("AkshatOS · Preview 0.3.0")
                    .font(.caption2).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
            }.padding(22)
        }
        .background(AppBackdrop())
        .navigationTitle("Pushup Reminder").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Pushup settings")
            }
        }
        .sheet(isPresented: $showSettings) { settings }
        .sheet(item: $store.summary) { session in summary(session) }
        .alert("Pushups need attention", isPresented: Binding(
            get: { store.message != nil }, set: { if !$0 { store.message = nil; store.messageRoute = nil } })) {
                if store.messageRoute == .notifications {
                    Button("Open Notification Settings") { openNotificationSettings(); store.message = nil; store.messageRoute = nil }
                } else if store.messageRoute == .location {
                    Button("Open Location Settings") { openLocationSettings(); store.message = nil; store.messageRoute = nil }
                }
                Button("OK") { store.message = nil; store.messageRoute = nil }
            } message: { Text(store.message ?? "") }
        .alert("Pushup Reminder", isPresented: Binding(
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
        AccentSurface(accent: Palette.lime) {
            VStack(alignment: .leading, spacing: 18) {
                AdaptiveRow {
                    VStack(alignment: .leading, spacing: 8) {
                        QuestBadge(text: "Reminder reactor", icon: "timer", accent: Palette.lime)
                        Label(store.operational, systemImage: stateIcon)
                            .font(.headline).foregroundStyle(Palette.lime)
                    }
                } trailing: {
                    ZStack {
                        Color.clear
                        if store.busy { ProgressView().tint(Palette.lime) }
                    }
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(!store.busy)
                }
                Group {
                    if store.nextReminder != nil {
                        TimelineView(.periodic(from: .now, by: reduceMotion ? 30 : 1)) { context in
                            let next = store.reminderDeadline(at: context.date) ?? context.date
                            let seconds = max(0, Int(ceil(next.timeIntervalSince(context.date))))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(String(format: "%02d:%02d", seconds / 60, seconds % 60))
                                    .font(.system(size: countdownSize, weight: .medium, design: .rounded)).monospacedDigit()
                                Text(store.active?.reminderCadenceAnchor.map { $0 <= context.date } == true
                                     ? "until the next automatic nudge"
                                     : "until the next scheduled reminder")
                                    .font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    } else {
                        Text(heroDescription).font(.body).foregroundStyle(Palette.muted)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: reminderAreaMinHeight, alignment: .topLeading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(heroAccessibilityLabel)
            heroActions
            Text("Every \(store.active?.interval ?? store.interval) min · then every 10 min until Done · Focus and iOS settings may silence alerts.")
                .font(.caption).foregroundStyle(Palette.muted)
        }
        .animation(interactionAnimation, value: store.busy)
        .animation(interactionAnimation, value: store.operational)
        .animation(interactionAnimation, value: store.todayCount)
        .animation(interactionAnimation, value: store.active?.id)
    }

    private var heroActions: some View {
        let hasUsableActiveDay = store.active != nil && !store.staleDay
        let showSettings = hasUsableActiveDay && store.operational == "Notifications blocked"
        let showManualPause = hasUsableActiveDay && store.active?.state == .running && store.operational != "Running"
        return Group {
            if store.active == nil {
                Button {
                    if store.today.isEmpty { startRequested() } else { showRestart = true }
                } label: {
                    Text(store.today.isEmpty ? "Start my day" : "Start another session")
                }
                .buttonStyle(ActionStyle(primary: true))
                .disabled(store.busy || !store.storageAvailable)
            } else {
                VStack(spacing: 12) {
                    Button {
                        Task {
                            if store.operational == "Running" { await store.pause() }
                            else { await store.resume() }
                        }
                    } label: {
                        Text(primaryActionTitle)
                    }
                    .buttonStyle(ActionStyle(primary: true))
                    .disabled(!primaryActionAvailable || store.busy || !store.storageAvailable)
                    .opacity(primaryActionAvailable ? 1 : 0)
                    .allowsHitTesting(primaryActionAvailable)
                    .accessibilityHidden(!primaryActionAvailable)

                    if showSettings {
                        Button("Open iOS notification settings") { openNotificationSettings() }
                            .buttonStyle(ActionStyle())
                            .disabled(store.busy)
                    }

                    if showManualPause {
                        Button("Pause until I resume") { Task { await store.pause() } }
                            .buttonStyle(ActionStyle())
                            .disabled(store.busy)
                    }

                    Button("End my day") { showEnd = true }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity)
                        .disabled(store.busy || !store.storageAvailable)
                }
            }
        }
    }

    private var primaryActionAvailable: Bool { store.active == nil || !store.staleDay }

    private var primaryActionTitle: String {
        guard let active = store.active else { return "Start my day" }
        if store.operational == "Running" { return "Pause reminders" }
        return active.state == .paused ? "Resume reminders" : "Repair reminders"
    }

    private var canUndo: Bool {
        guard let active = store.active else { return false }
        return active.count > 0 && !store.staleDay
    }

    private var powerProgress: Double {
        guard let goal = store.todayGoal, goal > 0 else {
            return min(1, Double(store.todayCount) / 8)
        }
        return min(1, Double(store.todayCount) / Double(goal))
    }

    private var powerStatus: String {
        guard let goal = store.todayGoal, goal > 0 else {
            return store.todayCount == 0 ? "Ready player one" : "Momentum online"
        }
        if store.todayCount >= goal { return "Quest cleared" }
        if store.todayCount * 2 >= goal { return "Powering up" }
        return store.todayCount == 0 ? "Ready player one" : "Combo started"
    }

    private var powerStatusIcon: String {
        guard let goal = store.todayGoal, goal > 0, store.todayCount >= goal else { return "sparkles" }
        return "trophy.fill"
    }

    private var interactionAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 0.2)
    }

    private var heroDescription: String {
        if store.staleDay { return "A session from \(store.active!.day) is still open. End it before starting today; reminders have been stopped." }
        switch store.operational {
        case "Paused": return "Take your time. Your day stays open until you're ready to return."
        case "Day complete": return "Good work showing up. Your sets are saved for today."
        case "Notifications blocked": return "Notifications were turned off after your day started. Reminders won't arrive until you allow them again in iOS Settings."
        case "Reminder needs repair": return "The saved schedule is missing or needs the current action buttons. Re-arm it to continue."
        case "Storage unavailable": return "Local storage needs attention. Keep the app installed to preserve your data."
        default: return "Start when you're ready. Your first reminder comes one full interval later."
        }
    }

    private var goalCard: some View {
        AccentSurface(accent: Palette.gold) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    QuestBadge(text: "Today's quest", icon: "target", accent: Palette.gold)
                    Text("Fill the power bar")
                        .font(.system(.title3, design: .rounded, weight: .black))
                }
                Spacer()
                Image(systemName: store.todayGoal.map { store.todayCount >= $0 } == true
                      ? "trophy.fill" : "flame.fill")
                    .font(.title).foregroundStyle(Palette.gold).accessibilityHidden(true)
            }
            if let goal = store.todayGoal {
                AdaptiveRow {
                    Text(store.todayCount >= goal ? "Quest cleared — the trophy is yours." : "\(max(0, goal - store.todayCount)) pushup sets until clear")
                } trailing: {
                    Text("\(store.todayCount)/\(goal)").monospacedDigit()
                }.font(.subheadline).foregroundStyle(Palette.muted)
                    .accessibilityElement(children: .combine)
                ProgressView(value: Double(min(store.todayCount, goal)), total: Double(goal)).tint(Palette.lime)
                    .accessibilityLabel("Progress toward today's goal")
                    .accessibilityValue("\(min(store.todayCount, goal)) of \(goal) sets")
                Text("Your streak is safe until the day ends. There is still time to finish the quest.")
                    .font(.caption).foregroundStyle(Palette.muted)
                    .opacity(store.todayCount < goal ? 1 : 0)
                    .accessibilityHidden(store.todayCount >= goal)
            } else {
                Text("Daily quests are off. Choose a pushup-set goal in Settings to start a streak.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    stat("\(store.streaks.current)", "day streak")
                    stat("\(store.streaks.best)", "personal best")
                }
            } else {
                HStack(spacing: 32) {
                    stat("\(store.streaks.current)", "day streak")
                    stat("\(store.streaks.best)", "personal best")
                }
            }
        }
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuestBadge(text: "Combo log", icon: "list.bullet", accent: Palette.aqua)
            Text("Today's power trail").font(.system(.title3, design: .rounded, weight: .black))
            let events = store.todayCompletions
            if events.isEmpty {
                Text("Zero is just the loading screen. Finished pushup sets will land here.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            ForEach(Array(events.prefix(12))) { event in
                AdaptiveRow(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: event.kind == .done ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(Palette.lime).accessibilityHidden(true)
                        Text(eventTitle(event.kind)).font(.subheadline)
                    }
                } trailing: {
                    Text(event.date, style: .time).font(.caption).foregroundStyle(Palette.muted)
                }.padding(.vertical, 5)
                    .accessibilityElement(children: .combine)
            }
            Text("Past quests").font(.system(.title3, design: .rounded, weight: .black)).padding(.top, 8)
            if store.daySummaries.isEmpty {
                Text("Completed and active days will appear here.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            ForEach(store.daySummaries) { day in
                Button { store.summary = day } label: {
                    AdaptiveRow {
                        Label(day.started.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                              systemImage: "clock.arrow.circlepath")
                    } trailing: {
                        HStack {
                            Text("\(day.completedSets) pushup sets")
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }
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
                    Stepper(store.goal == 0 ? "Daily quest: not set" : "Daily quest: \(store.goal) pushup sets",
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
                        Text(store.notificationEverAuthorized
                             ? "Notifications were turned off. Reminders cannot be delivered until you allow them again in iOS Settings."
                             : "Notifications were denied. Allow them in iOS Settings to receive reminders.")
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
                    Label(dailyStartStatusText, systemImage: "sunrise")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("When no Pushup day is active, AkshatOS schedules a daily 9:00 AM invitation to start. Opening it never starts the timer automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Data management") {
                    Button {
                        do {
                            exportDocument = SquatsBackupDocument(data: try store.makeBackupData())
                            showExporter = true
                        } catch { store.message = error.localizedDescription; store.messageRoute = nil }
                    } label: { Label("Export Pushup backup", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("export-pushups-backup")
                    Button { showImporter = true } label: {
                        Label("Restore Pushup backup", systemImage: "square.and.arrow.down")
                    }.accessibilityIdentifier("restore-pushups-backup")
                    Button("Delete completed history", role: .destructive) { showDeleteHistory = true }
                        .accessibilityIdentifier("delete-pushups-history")
                    Text("Backups are versioned JSON files stored wherever you choose in Files. Restore accepts your existing Squats-era backups and validates the entire file before replacing local Pushup data.")
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
                            Text(store.homeEverAuthorized
                                 ? "Location access was turned off after being granted. Enable it again in iOS Settings to use Home auto-pause."
                                 : "Location access was denied. Enable it in iOS Settings to use Home auto-pause.")
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
                    Text("Done logs one set and restarts the full interval. Pause stops reminders until you resume. If you ignore a reminder, AkshatOS nudges you automatically every 10 minutes until you choose Done or Pause.")
                        .accessibilityIdentifier("notification-actions-help")
                }
            }.navigationTitle("Pushup settings")
                .toolbar { Button("Done") { showSettings = false } }
        }.tint(Palette.lime)
            .animation(interactionAnimation, value: store.busy)
            .animation(interactionAnimation, value: store.homeEnabled)
            .animation(interactionAnimation, value: store.notificationAuthorization)
            .animation(interactionAnimation, value: store.homeAuthorization)
            .sheet(isPresented: $showHomeSetup) { HomeSetupView() }
            .confirmationDialog("Restore this Pushup backup?", isPresented: $showRestore,
                                titleVisibility: .visible) {
                Button("Replace current Pushup data", role: .destructive) {
                    if let pendingRestore { Task { await store.restore(pendingRestore) } }
                    pendingRestore = nil
                }
                Button("Cancel", role: .cancel) { pendingRestore = nil }
            } message: {
                Text("This replaces current Pushup history and settings with \(pendingRestore?.sessions.count ?? 0) saved sessions and stops the current reminder schedule.")
            }
            .confirmationDialog("Delete completed Pushup history?", isPresented: $showDeleteHistory,
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
                          contentType: .json, defaultFilename: "pushups-backup") { result in
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
            .alert("Pushups need attention", isPresented: Binding(
                get: { store.message != nil }, set: { if !$0 { store.message = nil; store.messageRoute = nil } })) {
                    if store.messageRoute == .notifications {
                        Button("Open Notification Settings") { openNotificationSettings(); store.message = nil; store.messageRoute = nil }
                    } else if store.messageRoute == .location {
                        Button("Open Location Settings") { openLocationSettings(); store.message = nil; store.messageRoute = nil }
                    }
                    Button("OK") { store.message = nil; store.messageRoute = nil }
                } message: { Text(store.message ?? "") }
            .alert("Pushup Reminder", isPresented: Binding(
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
        case .denied: return store.notificationEverAuthorized ? "Notifications turned off" : "Notifications denied"
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

    private var dailyStartStatusText: String {
        if store.dailyStartReminderScheduled { return "Daily 9:00 AM start reminder scheduled" }
        if store.active != nil { return "Daily start reminder is inactive during a Pushup day" }
        return "Daily 9:00 AM start reminder needs notification access"
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

    private static let homeHealthValues: Set<String> = ["At Home", "Away from Home", "Checking Home boundary", "Confirm Home boundary"]

    private var homeHealthIcon: String {
        guard store.homeEnabled else { return "house" }
        return Self.homeHealthValues.contains(store.homeHealth) ? "house.fill" : "exclamationmark.triangle"
    }

    private var homeHealthIsDegraded: Bool {
        store.homeEnabled && homeHealthIcon == "exclamationmark.triangle"
    }

    private var heroAccessibilityLabel: String {
        var parts = [store.operational]
        if let date = store.primaryReminder {
            let prefix = store.primaryReminderIsAutomaticNudge ? "Next automatic nudge" : "Next reminder"
            parts.append("\(prefix) around \(date.formatted(date: .omitted, time: .shortened))")
        } else {
            parts.append(heroDescription)
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
                    QuestBadge(text: "Quest recap", icon: "trophy.fill", accent: Palette.gold)
                    Text("Power gained.\nDay saved.").font(.system(.largeTitle, design: .rounded, weight: .black))
                    AccentSurface(accent: Palette.gold) {
                        Text("\(day.completedSets)").font(.system(size: summaryCountSize, weight: .bold, design: .rounded)).foregroundStyle(Palette.lime)
                        Text("pushup sets completed this day").foregroundStyle(Palette.muted)
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
                                AdaptiveRow {
                                    Text("\(pause.started.formatted(date: .omitted, time: .shortened))–\(pause.ended.formatted(date: .omitted, time: .shortened))")
                                } trailing: {
                                    Text(duration(pause.duration)).foregroundStyle(Palette.muted)
                                }.font(.subheadline)
                            }
                        }
                    }
                    Surface {
                        Label("Daily timeline", systemImage: "list.bullet").font(.headline)
                        if day.events.isEmpty { Text("No activity was logged.").foregroundStyle(Palette.muted) }
                        ForEach(day.events) { event in
                            AdaptiveRow {
                                Text(eventTitle(event.kind))
                            } trailing: {
                                Text(event.date, style: .time).foregroundStyle(Palette.muted)
                            }.font(.subheadline)
                        }
                    }
                }.padding(24)
            }.background(AppBackdrop()).navigationTitle("Quest recap")
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
        case .done: return "Pushup set completed"
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
        case .reached: return "Quest cleared: \(day.completedSets)/\(day.goal!) pushup sets."
        case .atRisk: return "Quest in progress: \(day.completedSets)/\(day.goal!) pushup sets."
        case .missed: return "Quest not cleared: \(day.completedSets)/\(day.goal!) pushup sets."
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
