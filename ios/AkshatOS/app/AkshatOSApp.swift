import SwiftUI

@main
struct AkshatOSApp: App {
    @StateObject private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            HubRootView(squats: services.squats)
                .preferredColorScheme(.dark)
        }
    }
}

/// Composition root: app-lifetime services must never be owned by navigation destinations.
@MainActor final class AppServices: ObservableObject {
    let notifications = AppNotificationCoordinator()
    let squats = SquatStore()
}
