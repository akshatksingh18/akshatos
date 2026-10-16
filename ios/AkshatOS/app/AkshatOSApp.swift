import SwiftUI
import Combine

@main
struct AkshatOSApp: App {
    @UIApplicationDelegateAdaptor(AkshatAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            HubRootView(services: delegate.services)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    Task {
                        if !delegate.services.preferences.fitnessStopped { await delegate.services.squats.refresh() }
                        delegate.services.studyLog.load(); delegate.services.todo.load(); delegate.services.journal.load()
                        delegate.services.personalNotifications.reconcile()
                    }
                }
        }
    }
}

/// Composition root: app-lifetime services must never be owned by navigation destinations.
@MainActor final class AppServices: ObservableObject {
    static let shared = AppServices()
    let squats: SquatStore
    let pageVault: PageVaultStore
    let liftLog: LiftLogStore
    let bodyLog: BodyLogStore
    let studyLog: StudyLogStore
    let todo: TodoStore
    let journal: JournalStore
    let watchlist: WatchlistStore
    let spending: SpendingStore
    let preferences: PersonalPreferences
    let personalNotifications: PersonalNotifications
    let transfer: LinkedFolderService
    let backup: FullBackupService
    let notifications: AppNotificationCoordinator
    /// App-lifetime, like the stores: a notification can be tapped before any hub screen exists,
    /// and the request has to survive until one does.
    let navigator = HubNavigator()
    let orientation = OrientationGate()
    private var preferencesSubscription: AnyCancellable?

    init() {
        // ReelVault was removed after Build 32; delete the videos and records it left behind.
        RetiredModuleCleanup.run()
        let preferences = PersonalPreferences()
        self.preferences = preferences
        let home = HomeRegionService(enabled: { !preferences.fitnessStopped })
        squats = SquatStore(reminders: GatedSquatReminders(preferences: preferences), homeMonitor: home)
        pageVault = PageVaultStore()
        liftLog = LiftLogStore(reminders: GatedLiftReminders(preferences: preferences))
        bodyLog = BodyLogStore(reminders: GatedBodyReminders(preferences: preferences))
        studyLog = StudyLogStore()
        todo = TodoStore(); journal = JournalStore(); watchlist = WatchlistStore(); spending = SpendingStore()
        transfer = LinkedFolderService()
        personalNotifications = PersonalNotifications(study: studyLog, todo: todo, preferences: preferences)
        // Every module takes part in the full backup, in hub order. check-backup-coverage.py fails
        // CI if a module in features/ is missing from this list.
        backup = FullBackupService(parts: [squats, pageVault, liftLog, bodyLog, studyLog, todo, journal, watchlist, spending, preferences])
        notifications = AppNotificationCoordinator(squats: squats, liftLog: liftLog, navigator: navigator, personal: personalNotifications)
        let scheduler = personalNotifications
        studyLog.onChange = { scheduler.reconcile() }; todo.onChange = { scheduler.reconcile() }
        preferencesSubscription = preferences.objectWillChange.sink { _ in
            Task { @MainActor in await Task.yield(); scheduler.reconcile() }
        }
    }
}

@MainActor final class AkshatAppDelegate: NSObject, UIApplicationDelegate {
    let services = AppServices.shared

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Services and the notification delegate exist before launch finishes, including background launch.
        true
    }

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        services.orientation.supportedOrientations
    }
}
