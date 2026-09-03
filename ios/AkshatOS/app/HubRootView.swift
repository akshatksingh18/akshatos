import SwiftUI

/// Adapts feature state to the hub's display-only contract and injects destinations locally.
struct HubRootView: View {
    @ObservedObject var squats: SquatStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HubView(entries: [
            HubEntry(id: .squats, title: "Squat Reminder", subtitle: "Make room for a little movement.",
                     icon: "figure.strengthtraining.traditional", isAvailable: true,
                     status: squats.operational, detail: "\(squats.todayCount) sets today",
                     statusIcon: squats.active == nil ? "sun.max" : "circle.fill"),
            HubEntry(id: .pageVault, title: "PageVault", subtitle: "Your reading corner",
                     icon: "book.closed", isAvailable: false),
            HubEntry(id: .reelVault, title: "ReelVault", subtitle: "Your personal reel collection",
                     icon: "play.rectangle", isAvailable: false)
        ]) { route in
            switch route {
            case .squats:
                SquatDashboard().environmentObject(squats)
            case .pageVault, .reelVault:
                // Unavailable entries are never links. No media implementation is activated.
                EmptyView()
            }
        }
        .task { await squats.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await squats.refresh() } }
        }
    }
}
