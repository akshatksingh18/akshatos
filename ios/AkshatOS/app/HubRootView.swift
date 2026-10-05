import SwiftUI

/// Adapts feature state to the hub's display-only contract and injects destinations locally.
struct HubRootView: View {
    @ObservedObject var squats: SquatStore
    @ObservedObject var pageVault: PageVaultStore
    @ObservedObject var liftLog: LiftLogStore
    @ObservedObject var bodyLog: BodyLogStore
    let backup: FullBackupService
    @ObservedObject var navigator: HubNavigator
    let orientation: OrientationGate
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [HubRoute] = []

    var body: some View {
        HubView(entries: [
            HubEntry(id: .squats, title: "Pushup Reminder", subtitle: "Reminders for pushup sets",
                     icon: "figure.strengthtraining.functional", isAvailable: true,
                     status: squats.operational,
                     detail: squats.todayCount == 1 ? "1 set today" : "\(squats.todayCount) sets today"),
            HubEntry(id: .pageVault, title: "PageVault", subtitle: "PDF library",
                     icon: "book.closed", isAvailable: true,
                     status: pageVault.books.isEmpty ? "No books yet"
                        : pageVault.books.count == 1 ? "1 book" : "\(pageVault.books.count) books"),
            HubEntry(id: .liftLog, title: "Lift Log", subtitle: "Strength sessions",
                     icon: "dumbbell", isAvailable: true,
                     status: liftLog.active == nil ? "Ready" : "Workout in progress",
                     detail: liftLog.finished.count == 1 ? "1 session" : "\(liftLog.finished.count) sessions"),
            HubEntry(id: .body, title: "Body", subtitle: "Weight and measurements",
                     icon: "ruler", isAvailable: true,
                     status: bodyLog.todayWeight.map { String(format: "%.1f lb today", $0.pounds) } ?? "Not weighed today",
                     detail: bodyLog.thisWeekMeasurement == nil ? "Measure this week" : "Measured this week")
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
            case .body:
                BodyLogView(store: bodyLog)
            case .backup:
                FullBackupView(service: backup)
            }
        }
        .task {
            await squats.refresh()
            liftLog.load()
            bodyLog.load()
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
