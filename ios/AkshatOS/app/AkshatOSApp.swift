import SwiftUI

@main
struct AkshatOSApp: App {
    @UIApplicationDelegateAdaptor(AkshatAppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            HubRootView(squats: delegate.services.squats)
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
    let notifications: AppNotificationCoordinator

    init() {
        squats = SquatStore()
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
}
