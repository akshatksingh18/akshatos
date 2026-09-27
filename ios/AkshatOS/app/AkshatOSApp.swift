import SwiftUI

@main
struct AkshatOSApp: App {
    @UIApplicationDelegateAdaptor(AkshatAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            HubRootView(squats: delegate.services.squats,
                        pageVault: delegate.services.pageVault,
                        liftLog: delegate.services.liftLog,
                        navigator: delegate.services.navigator,
                        orientation: delegate.services.orientation)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    Task { await delegate.services.squats.refresh() }
                }
                .onOpenURL { url in delegate.services.openFile(url) }
        }
    }
}

/// Composition root: app-lifetime services must never be owned by navigation destinations.
@MainActor final class AppServices: ObservableObject {
    let squats: SquatStore
    let pageVault: PageVaultStore
    let liftLog: LiftLogStore
    let notifications: AppNotificationCoordinator
    /// App-lifetime, like the stores: a notification can be tapped before any hub screen exists,
    /// and the request has to survive until one does.
    let navigator = HubNavigator()
    let orientation = OrientationGate()

    init() {
        let home = HomeRegionService()
        squats = SquatStore(homeMonitor: home)
        pageVault = PageVaultStore()
        liftLog = LiftLogStore()
        notifications = AppNotificationCoordinator(squats: squats, navigator: navigator)
    }

    /// A file another app handed over ("Open in AkshatOS"). The app declares PDFs as the only type
    /// it opens, and PDFs belong to PageVault, so this is the one place that knows both: the file
    /// goes to PageVault and the hub opens it, the way a tapped notification opens its feature.
    func openFile(_ url: URL) {
        guard url.isFileURL, url.pathExtension.lowercased() == "pdf" else { return }
        navigator.request(.pageVault)
        Task { await pageVault.importOpenedFile(url) }
    }
}

@MainActor final class AkshatAppDelegate: NSObject, UIApplicationDelegate {
    let services = AppServices()

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
