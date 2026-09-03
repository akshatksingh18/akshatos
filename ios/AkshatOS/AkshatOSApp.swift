import SwiftUI

@main
struct AkshatOSApp: App {
    @StateObject private var squats = SquatStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HubView()
                .environmentObject(squats)
                .preferredColorScheme(.dark)
                .task { await squats.refresh() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await squats.refresh() } }
                }
        }
    }
}
