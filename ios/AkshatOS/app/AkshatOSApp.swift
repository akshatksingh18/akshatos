import SwiftUI

@main
struct AkshatOSApp: App {
    @UIApplicationDelegateAdaptor(AkshatAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            HubRootView(squats: delegate.services.squats,
                        pageVault: delegate.services.pageVault,
                        orientation: delegate.services.orientation)
                .preferredColorScheme(.dark)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
                    Task { await delegate.services.squats.refresh() }
                }
        }
    }
}

/// Composition root: app-lifetime services must never be owned by navigation destinations.
@MainActor final class AppServices: ObservableObject {
    let squats: SquatStore
    let pageVault: PageVaultStore
    let notifications: AppNotificationCoordinator
    let orientation = OrientationGate()

    init() {
        let home = HomeRegionService()
        squats = SquatStore(homeMonitor: home)
        pageVault = PageVaultStore()
        notifications = AppNotificationCoordinator(squats: squats)
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
