import SwiftUI

/// Adapts feature state to the hub's display-only contract and injects destinations locally.
struct HubRootView: View {
    @ObservedObject var squats: SquatStore
    @ObservedObject var pageVault: PageVaultStore
    @ObservedObject var navigator: HubNavigator
    let orientation: OrientationGate
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [HubRoute] = []

    var body: some View {
        HubView(entries: [
            HubEntry(id: .squats, title: "Squat Reminder", subtitle: "Make room for a little movement.",
                     icon: "figure.strengthtraining.traditional", isAvailable: true,
                     status: squats.operational, detail: "\(squats.todayCount) sets today",
                     statusIcon: squats.active == nil ? "sun.max" : "circle.fill"),
            HubEntry(id: .pageVault, title: "PageVault", subtitle: "Your reading corner",
                     icon: "book.closed", isAvailable: true,
                     status: pageVault.books.isEmpty ? "No books yet" : "Reading",
                     detail: pageVault.books.isEmpty ? "" : "\(pageVault.books.count) in library",
                     statusIcon: "book"),
            HubEntry(id: .reelVault, title: "ReelVault", subtitle: "Your personal reel collection",
                     icon: "play.rectangle", isAvailable: false)
        ], path: $path) { route in
            switch route {
            case .squats:
                SquatDashboard().environmentObject(squats)
            case .pageVault:
                PageVaultLibraryView(store: pageVault) { reading in
                    orientation.setReadingSession(reading)
                }
            case .reelVault:
                // Unavailable entries are never links. No reel implementation is activated.
                EmptyView()
            }
        }
        .task { await squats.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await squats.refresh() } }
        }
        // A tapped notification opens the feature that sent it. Replacing the path rather than
        // appending is what makes that true from anywhere: whatever was open — PageVault, a book,
        // a sheet's parent — is left behind instead of the feature being pushed on top of it.
        .onChange(of: navigator.requested) { _, route in
            guard let route else { return }
            if path != [route] { path = [route] }
            navigator.clear()
        }
    }
}
