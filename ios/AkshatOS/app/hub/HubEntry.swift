/// Hub metadata contains no feature stores, persistence models, or business commands.
enum HubRoute: String {
    case squats, pageVault, reelVault
}

struct HubEntry: Identifiable {
    let id: HubRoute
    let title: String
    let subtitle: String
    let icon: String
    let isAvailable: Bool
    var status = ""
    var detail = ""
    var statusIcon = "circle.fill"
}
