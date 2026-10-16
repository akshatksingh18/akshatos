import SwiftUI

struct HubRootView: View {
    let services: AppServices
    @ObservedObject private var navigator: HubNavigator
    @ObservedObject private var study: StudyLogStore
    @Environment(\.scenePhase) private var phase
    @State private var tab = PersonalHubTab.today
    @State private var appPath: [HubRoute] = []
    @State private var tomorrowPlan = false
    @State private var legacyRoute: HubRoute?
    init(services: AppServices) { self.services = services; _navigator = ObservedObject(wrappedValue: services.navigator); _study = ObservedObject(wrappedValue: services.studyLog) }
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                PersonalTodayView(study: services.studyLog, todo: services.todo, journal: services.journal, preferences: services.preferences, orientation: services.orientation, studyActivity: services.studyActivity,
                    keepGoing: { services.preferences.lastStudyConfirmation = Date(); services.personalNotifications.reconcile() },
                    openTodo: { tab = .todo })
            }.tabItem { Label("Today", systemImage: "calendar") }.tag(PersonalHubTab.today)
            NavigationStack { TodoView(store: services.todo) }
                .tabItem { Label("To-do", systemImage: "checklist") }.tag(PersonalHubTab.todo)
            NavigationStack {
                JournalView(store: services.journal, facts: { services.facts($0) }, planTomorrow: { tomorrowPlan = true })
            }.tabItem { Label("Journal", systemImage: "book.closed") }.tag(PersonalHubTab.journal)
            NavigationStack(path: $appPath) {
                PersonalAppsView(services: services)
                    .navigationDestination(for: HubRoute.self) { route in destination(route) }
            }.tabItem { Label("Apps", systemImage: "square.grid.2x2") }.tag(PersonalHubTab.apps)
        }
        .tint(HubInk.copper)
        .onOpenURL { url in
            if url.scheme == "akshatos", url.host == "study", url.path.isEmpty { navigator.request(.studyLog) }
        }
        .task { await refresh() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            services.studyLog.refreshDay(); services.todo.refreshDay(); services.journal.refreshDay()
        }
        .onChange(of: phase) { _, phase in
            if phase == .background { services.journal.lock() }
            if phase == .active { Task { await refresh() } }
        }
        .onChange(of: navigator.requested, initial: true) { _, route in
            guard let route else { return }
            switch route {
            case .studyLog: tab = .today
            case .todo: tab = .todo
            case .journal: tab = .journal
            case .squats, .liftLog, .body:
                if !services.preferences.fitnessStopped { legacyRoute = route }
            default: tab = .apps; appPath = [route]
            }
            navigator.clear()
        }
        .sheet(isPresented: $tomorrowPlan) {
            PriorityPicker(store: services.todo, day: services.todo.clock.shifted(services.todo.today, by: 1) ?? services.todo.today)
        }
        .sheet(item: Binding(get: { services.studyLog.runningRestoreReview }, set: { if $0 == nil { services.studyLog.finishRunningRestore(nil) } })) { review in
            StudyRunningRestoreView(store: services.studyLog, review: review)
        }
        .sheet(isPresented: Binding(get: { legacyRoute != nil }, set: { if !$0 { legacyRoute = nil } })) {
            NavigationStack { if let legacyRoute { destination(legacyRoute).toolbar { Button("Close") { self.legacyRoute = nil } } } }
        }
        .overlay {
            if phase != .active { HubInk.background.ignoresSafeArea().overlay { Label("AkshatOS", systemImage: "lock.fill").foregroundStyle(.secondary) } }
        }
    }
    @ViewBuilder private func destination(_ route: HubRoute) -> some View {
        switch route {
        case .pageVault: PageVaultLibraryView(store: services.pageVault) { services.orientation.setReadingSession($0) }
        case .watchlist: WatchlistView(store: services.watchlist)
        case .spending: SpendingView(store: services.spending)
        case .backup: FullBackupView(service: services.backup)
        case .studyLog: StudyPreferencesView(store: services.studyLog)
        case .todo: TodoView(store: services.todo)
        case .journal: JournalView(store: services.journal, facts: { services.facts($0) }, planTomorrow: { tomorrowPlan = true })
        case .squats: SquatDashboard().environmentObject(services.squats)
        case .liftLog: LiftLogView(store: services.liftLog)
        case .body: BodyLogView(store: services.bodyLog)
        }
    }
    private func refresh() async {
        services.studyLog.refreshDay(); services.todo.refreshDay(); services.journal.refreshDay()
        if !services.preferences.fitnessStopped { await services.squats.refresh() }
        services.liftLog.load(); services.bodyLog.load(); services.studyLog.load()
        services.todo.load(); services.journal.load(); services.watchlist.load(); services.spending.load()
        services.personalNotifications.reconcile()
        services.studyActivity.reconcile()
        if services.transfer.linked { await services.transfer.checkWatchlist(after: services.watchlist.state.metadataRevision) }
    }
}

private enum PersonalHubTab: String { case today, todo, journal, apps }

extension AppServices {
    func facts(_ day: String) -> JournalDayFacts {
        let date = Date(), plan = todo.plan(day)
        let reading = day == studyLog.today ? pageVault.current : nil
        return JournalDayFacts(activityDay: day, capturedAt: date,
            studySeconds: studyLog.storageAvailable ? studyLog.log.studied(on: day, now: date, clock: studyLog.clock) : nil,
            studyBlocks: studyLog.storageAvailable ? studyLog.log.blocks(now: date, clock: studyLog.clock).filter { $0.day == day }.count : nil,
            completedTasks: todo.available ? todo.state.tasks.filter { $0.completedAt.map { todo.clock.key($0) == day } == true }.count : nil,
            selectedPriorities: todo.available ? plan?.selected.count : nil,
            completedPriorities: todo.available ? plan?.completed.count : nil,
            readingTitle: pageVault.storageAvailable ? reading?.title : nil,
            readingPage: pageVault.storageAvailable ? reading.map { $0.currentPage + 1 } : nil)
    }
}
