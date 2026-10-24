import SwiftUI

struct HubRootView: View {
    let services: AppServices
    @ObservedObject private var navigator: HubNavigator
    @ObservedObject private var study: StudyLogStore
    @Environment(\.scenePhase) private var phase
    @State private var tab = PersonalHubTab.today
    @State private var appPath: [HubRoute] = []
    @State private var legacyRoute: HubRoute?
    init(services: AppServices) { self.services = services; _navigator = ObservedObject(wrappedValue: services.navigator); _study = ObservedObject(wrappedValue: services.studyLog) }
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                PersonalTodayView(study: services.studyLog, todo: services.todo, preferences: services.preferences, orientation: services.orientation, studyActivity: services.studyActivity,
                    keepGoing: { services.preferences.lastStudyConfirmation = Date(); services.personalNotifications.reconcile() },
                    openTodo: { tab = .todo })
            }.tabItem { Label("Today", systemImage: "calendar") }.tag(PersonalHubTab.today)
            NavigationStack { TodoView(store: services.todo) }
                .tabItem { Label("To-do", systemImage: "checklist") }.tag(PersonalHubTab.todo)
            NavigationStack(path: $appPath) {
                PersonalAppsView(services: services)
                    .navigationDestination(for: HubRoute.self) { route in destination(route) }
            }.tabItem { Label("Apps", systemImage: "square.grid.2x2") }.tag(PersonalHubTab.apps)
        }
        .tint(HubInk.accent)
        .onOpenURL { url in
            if url.scheme == "akshatos", url.host == "study", url.path.isEmpty { navigator.request(.studyLog) }
        }
        .task { await refresh() }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            services.studyLog.refreshDay(); services.todo.refreshDay()
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
            case .journal: tab = .apps; appPath = [] // Retired route must never reopen Journal.
            case .squats, .liftLog, .body:
                if !services.preferences.fitnessStopped { legacyRoute = route }
            default: tab = .apps; appPath = [route]
            }
            navigator.clear()
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
        case .journal: PersonalAppsView(services: services)
        case .squats: SquatDashboard().environmentObject(services.squats)
        case .liftLog: LiftLogView(store: services.liftLog)
        case .body: BodyLogView(store: services.bodyLog)
        }
    }
    private func refresh() async {
        services.studyLog.refreshDay(); services.todo.refreshDay()
        if !services.preferences.fitnessStopped { await services.squats.refresh() }
        services.liftLog.load(); services.bodyLog.load(); services.studyLog.load()
        services.todo.load(); services.journal.load(); services.watchlist.load(); services.spending.load()
        services.personalNotifications.reconcile()
        services.studyActivity.reconcile()
        if services.transfer.linked { await services.transfer.checkWatchlist(after: services.watchlist.state.metadataRevision) }
        if services.transfer.linked { await services.transfer.checkStudy() }
    }
}

private enum PersonalHubTab: String { case today, todo, apps }
