import SwiftUI
import UniformTypeIdentifiers

struct PersonalAppsView: View {
    let services: AppServices
    @ObservedObject private var pageVault: PageVaultStore
    @State private var search = false
    init(services: AppServices) { self.services = services; _pageVault = ObservedObject(wrappedValue: services.pageVault) }
    var body: some View {
        List {
            NavigationLink(value: HubRoute.pageVault) {
                HStack(spacing: 14) {
                    HubBookArtwork(symbol: "book.closed")
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PageVault").font(.title3.weight(.medium))
                        Text(pageVault.current.map { "Continue \($0.title) · page \($0.currentPage + 1)" } ?? "Read and listen")
                            .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }.padding(.vertical, 14)
                }
            }.accessibilityIdentifier("open-pageVault")
            NavigationLink(value: HubRoute.watchlist) { Label("Watchlist", systemImage: "film").padding(.vertical, 12) }.accessibilityIdentifier("open-watchlist")
            NavigationLink(value: HubRoute.spending) { Label("Spending", systemImage: "creditcard").padding(.vertical, 12) }.accessibilityIdentifier("open-spending")
            Section {
                NavigationLink { PersonalSettingsView(services: services) } label: { Label("Settings & backup", systemImage: "slider.horizontal.3").padding(.vertical, 10) }.accessibilityIdentifier("open-personal-settings")
                NavigationLink(value: HubRoute.backup) { Label("Back up everything", systemImage: "externaldrive") }.accessibilityIdentifier("open-backup")
            }
        }.personalList().navigationTitle("Apps")
        .toolbar { Button { search = true } label: { Label("Search", systemImage: "magnifyingglass") } }
        .sheet(isPresented: $search) { NavigationStack { PersonalSearchView(todo: services.todo, journal: services.journal) } }
    }
}

struct PersonalSettingsView: View {
    let services: AppServices
    @ObservedObject private var preferences: PersonalPreferences
    @ObservedObject private var journal: JournalStore
    @ObservedObject private var scheduler: PersonalNotifications
    init(services: AppServices) {
        self.services = services
        _preferences = ObservedObject(wrappedValue: services.preferences)
        _journal = ObservedObject(wrappedValue: services.journal)
        _scheduler = ObservedObject(wrappedValue: services.personalNotifications)
    }
    var body: some View {
        Form {
            Section("Study") {
                NavigationLink("Target, marks and blocks") { StudyPreferencesView(store: services.studyLog) }.accessibilityIdentifier("open-studyLog")
                Toggle("Still studying?", isOn: $preferences.stillStudying)
                if preferences.stillStudying { Stepper("Every \(preferences.checkMinutes) minutes", value: $preferences.checkMinutes, in: 5...120, step: 5) }
                Toggle("Back to it?", isOn: $preferences.breakReminder)
                if preferences.breakReminder { Stepper("After \(preferences.breakMinutes) minutes on a break", value: $preferences.breakMinutes, in: 5...180, step: 5) }
            }
            Section("Journal privacy") {
                Toggle("Require Face ID / passcode", isOn: Binding(get: { journal.lockEnabled }, set: { value in Task { await journal.setLockEnabled(value) } }))
                Text("The lock protects every Journal screen and preview. Exported Markdown, photos and full backups are not encrypted by this screen lock.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Reminders") {
                Button("Allow notifications / retry") { Task { await scheduler.requestPermission() } }
                Toggle("Morning plan invitation", isOn: $preferences.morningPlan)
                if preferences.morningPlan { Stepper("At \(preferences.morningHour):00", value: $preferences.morningHour, in: 0...23); Text("One upcoming invitation before study starts, refreshed when you use the app.").font(.footnote).foregroundStyle(.secondary) }
                Toggle("Daily Journal invitation", isOn: $preferences.journalReminder)
                if preferences.journalReminder { Stepper("At \(preferences.journalHour):00", value: $preferences.journalHour, in: 0...23) }
                Text("An optional generic daily invitation, including days with an entry. Timed task reminders have a finite rolling window; return to the app to refresh it.").font(.footnote).foregroundStyle(.secondary)
                Toggle("Badge: priorities remaining", isOn: $preferences.badge)
                Text(scheduler.status).font(.footnote).foregroundStyle(.secondary)
            }
            Section("Motivation") {
                Toggle("Optional full-day challenge", isOn: $preferences.fullDayChallenge)
                Text("Study mark + all chosen priorities + a saved Journal entry marked Done. No priorities means unplanned. Fitness is not included; the open day does not break a streak.").font(.footnote).foregroundStyle(.secondary)
            }
            Section("Files and recovery") {
                NavigationLink("Linked folder") { LinkedFolderView(services: services) }
                NavigationLink { FullBackupView(service: services.backup) } label: { Text("Back up / restore everything") }
            }
            Section {
                NavigationLink { FitnessTransitionView(services: services) } label: {
                    Label(preferences.fitnessStopped ? "Previous fitness data" : "Finish WHOOP handover", systemImage: "arrow.right.arrow.left")
                }.accessibilityIdentifier("fitness-transition")
            } footer: { Text("Fitness belongs in WHOOP. Legacy data stays recoverable here; the daily hub has no fitness cards or requirements.") }
        }.personalList().navigationTitle("Settings & backup")
        .onReceive(preferences.objectWillChange) { _ in Task { @MainActor in await Task.yield(); scheduler.reconcile() } }
        .personalMessage("Journal privacy", message: $journal.message)
    }
}

private struct FitnessTransitionView: View {
    let services: AppServices
    @ObservedObject private var preferences: PersonalPreferences
    @State private var verified = false
    @State private var confirming = false
    @State private var message: String?
    init(services: AppServices) { self.services = services; _preferences = ObservedObject(wrappedValue: services.preferences) }
    var body: some View {
        Form {
            Section {
                Text("Pushup Reminder, Lift Log and Body now belong in WHOOP. Their old AkshatOS stores are retained for recovery, not daily progress.")
                NavigationLink { FullBackupView(service: services.backup) } label: { Text("Back up old and new data") }
            }
            if !preferences.fitnessStopped {
                Section("Review before switching") {
                    NavigationLink { SquatDashboard().environmentObject(services.squats) } label: { Text("Previous Pushup Reminder") }.accessibilityIdentifier("open-squats")
                    NavigationLink { LiftLogView(store: services.liftLog) } label: { Text("Previous Lift Log") }.accessibilityIdentifier("open-liftLog")
                    NavigationLink { BodyLogView(store: services.bodyLog) } label: { Text("Previous Body") }.accessibilityIdentifier("open-body")
                    Toggle("WHOOP imports, photos, reminders and recovery checked on my phone", isOn: $verified)
                    Button("Stop old fitness reminders") { confirming = true }.disabled(!verified)
                }
            } else {
                Section { Label("Old reminder ownership stopped", systemImage: "checkmark.circle"); Text("History remains in full backup. No automatic WHOOP synchronization is enabled.").font(.footnote).foregroundStyle(.secondary) }
            }
        }.personalList().navigationTitle("WHOOP handover").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Stop the old fitness reminders?", isPresented: $confirming, titleVisibility: .visible) {
            Button("Stop old reminders") { Task { await handOver() } }
        } message: { Text("This ends the old Pushups day and removes its Home boundary and reminders, plus Body/Lift reminders. It does not delete history or start anything in WHOOP.") }
        .personalMessage("WHOOP handover", message: $message)
    }
    private func handOver() async {
        services.liftLog.load()
        guard services.liftLog.storageAvailable, services.squats.storageAvailable, services.bodyLog.storageAvailable else {
            message = "Load and back up the old fitness stores before switching."; return
        }
        guard services.liftLog.active == nil else { message = "Finish or discard the old open Lift Log workout before switching."; return }
        await services.squats.end()
        guard services.squats.active == nil else { message = "The old Pushups day could not be ended. Keep its current data and retry."; return }
        await services.squats.disableHome()
        guard services.squats.homeState == nil else { message = "The old Home boundary could not be disabled. Retry before switching."; return }
        await services.bodyLog.setReminder(enabled: false)
        await services.liftLog.settleReminder()
        preferences.fitnessStopped = true
        ReminderService().cancel(); ReminderService().cancelDailyStartReminder(); LiftReminderService().cancel()
        services.personalNotifications.reconcile()
        message = "Old fitness reminders stopped. History and backups are retained."
    }
}

private struct LinkedFolderView: View {
    let services: AppServices
    @ObservedObject private var transfer: LinkedFolderService
    @ObservedObject private var watchlist: WatchlistStore
    @State private var selecting = false
    @State private var exportingStudy = false
    @State private var document: PortableDocument?
    init(services: AppServices) {
        self.services = services; _transfer = ObservedObject(wrappedValue: services.transfer); _watchlist = ObservedObject(wrappedValue: services.watchlist)
    }
    var body: some View {
        Form {
            Section {
                Button(transfer.linked ? "Re-link folder" : "Choose folder in Files") { selecting = true }
                if transfer.linked { Button("Unlink folder", role: .destructive) { transfer.unlink() } }
                Text(transfer.status).font(.footnote).foregroundStyle(.secondary)
                if let date = transfer.lastRead { LabeledContent("Last read", value: date.formatted()) }
                if let date = transfer.lastWrite { LabeledContent("Last export", value: date.formatted()) }
            } footer: { Text("A file hand-off, not continuous two-way sync. Provider latency and re-signing must be tested. Missing files never delete phone records. Journal is never exported automatically.") }
            Section("Watchlist") {
                Button("Check linked Watchlist") { Task { await transfer.checkWatchlist(after: watchlist.state.metadataRevision) } }.disabled(!transfer.linked || transfer.busy)
                if transfer.newWatchlistAvailable { Button("Preview new titles") { transfer.previewWatchlist(in: watchlist) } }
                Button("Export watched events to linked folder") {
                    Task { do { await transfer.write(try watchlist.watchedExport(), file: .watched) } catch { watchlist.message = error.localizedDescription } }
                }.disabled(!transfer.linked || transfer.busy)
                NavigationLink { WatchlistView(store: services.watchlist) } label: { Text("Manual import / export") }
            }
            Section("Study → laptop") {
                Button("Export finished study sessions") {
                    do { document = PortableDocument(data: try services.studyExport()); exportingStudy = true }
                    catch { watchlist.message = error.localizedDescription }
                }
                Button("Send finished sessions to linked folder") {
                    Task { do { await transfer.write(try services.studyExport(), file: .study) } catch { watchlist.message = error.localizedDescription } }
                }.disabled(!transfer.linked || transfer.busy)
                Text("Finished records only. Preview and reconcile on the laptop; an export does not mark curriculum complete or prove a transfer arrived.").font(.footnote).foregroundStyle(.secondary)
            }
        }.personalList().navigationTitle("Linked folder")
        .fileImporter(isPresented: $selecting, allowedContentTypes: [.folder]) { result in if case .success(let url) = result { transfer.link(url) } }
        .fileExporter(isPresented: $exportingStudy, document: document, contentType: .json, defaultFilename: "study-sessions") { result in if case .failure(let error) = result { watchlist.message = error.localizedDescription } }
        .alert("Import Watchlist revision?", isPresented: Binding(get: { watchlist.pendingImport != nil }, set: { if !$0 { watchlist.pendingImport = nil } })) {
            Button("Import") { watchlist.applyImport() }; Button("Cancel", role: .cancel) { watchlist.pendingImport = nil }
        } message: { Text(watchlist.importDescription) }
        .personalMessage("File hand-off", message: $watchlist.message)
    }
}

private struct PersonalSearchView: View {
    @ObservedObject var todo: TodoStore
    @ObservedObject var journal: JournalStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    var body: some View {
        List {
            if !query.isEmpty {
                Section("To-do") { ForEach(todo.visible.filter { ($0.title + " " + $0.note).localizedCaseInsensitiveContains(query) }) { Text($0.title) } }
                Section("After study") { ForEach(todo.state.thoughts.filter { $0.text.localizedCaseInsensitiveContains(query) }) { Text($0.text) } }
                if journal.isLocked {
                    Button("Unlock Journal to search its entries") { Task { _ = await journal.authenticate(reason: "Search private Journal entries") } }
                } else {
                    Section("Journal") {
                        ForEach(journal.entries.filter { ($0.text + " " + $0.wentWell + " " + $0.change + " " + $0.learned).localizedCaseInsensitiveContains(query) }) { entry in
                            VStack(alignment: .leading) { Text(entry.day).font(.caption).foregroundStyle(.secondary); Text(entry.text).lineLimit(3) }
                        }
                    }
                }
            } else { Text("Find a task, parked thought or unlocked Journal entry.").foregroundStyle(.secondary) }
        }.personalList().navigationTitle("Search").searchable(text: $query).toolbar { Button("Close") { dismiss() } }
    }
}
