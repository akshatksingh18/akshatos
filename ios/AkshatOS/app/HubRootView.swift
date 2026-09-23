import SwiftUI

/// Adapts feature state to the hub's display-only contract and injects destinations locally.
struct HubRootView: View {
    @ObservedObject var squats: SquatStore
    @ObservedObject var pageVault: PageVaultStore
    @ObservedObject var liftLog: LiftLogStore
    @ObservedObject var navigator: HubNavigator
    let orientation: OrientationGate
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [HubRoute] = []

    var body: some View {
        HubView(entries: [
            HubEntry(id: .squats, title: "Pushup Reminder", subtitle: "Drop, press, and power up your day.",
                     icon: "bolt.fill", isAvailable: true,
                     status: squats.operational, detail: "\(squats.todayCount) pushup sets",
                     statusIcon: squats.active == nil ? "sun.max" : "circle.fill"),
            HubEntry(id: .pageVault, title: "PageVault", subtitle: "Open a portal. Keep what you find.",
                     icon: "book.closed", isAvailable: true,
                     status: pageVault.books.isEmpty ? "Vault is waiting" : "Vault online",
                     detail: pageVault.books.isEmpty ? "Add your first PDF" : "\(pageVault.books.count) books",
                     statusIcon: "book"),
            HubEntry(id: .liftLog, title: "Lift Log", subtitle: "Record every working set your way.",
                     icon: "dumbbell.fill", isAvailable: true,
                     status: liftLog.active == nil ? "Ready to train" : "Workout in progress",
                     detail: "\(liftLog.finished.count) sessions · \(liftLog.totalSetCount) sets",
                     statusIcon: "chart.line.uptrend.xyaxis"),
            HubEntry(id: .reelVault, title: "ReelVault", subtitle: "A future portal for the good stuff.",
                     icon: "play.rectangle", isAvailable: false)
        ], path: $path) { route in
            switch route {
            case .squats:
                SquatDashboard().environmentObject(squats)
            case .pageVault:
                PageVaultLibraryView(store: pageVault) { reading in
                    orientation.setReadingSession(reading)
                }
            case .liftLog:
                LiftLogView(store: liftLog)
            case .reelVault:
                // Unavailable entries are never links. No reel implementation is activated.
                EmptyView()
            }
        }
        .task {
            await squats.refresh()
            liftLog.load()
        }
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
