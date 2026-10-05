/// Hub metadata contains no feature stores, persistence models, or business commands.
enum HubRoute: String {
    case squats, pageVault, liftLog, body
    /// Not a module: the one screen that backs up and restores all of them.
    case backup
}

struct HubEntry: Identifiable {
    let id: HubRoute
    let title: String
    let subtitle: String
    let icon: String
    let isAvailable: Bool
    var status = ""
    var detail = ""
}
