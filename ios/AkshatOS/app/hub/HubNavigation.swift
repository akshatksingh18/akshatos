import Combine

/// Where the hub has been asked to go, so something outside the hub can open a feature.
///
/// A tapped alert should land on the feature that sent it, not on whatever happened to be open
/// last. The hub cannot work that out for itself — it holds no alerts and no services — so it is
/// told, through this. The request is plain hub state: no feature types, no persistence, no
/// system frameworks, which keeps the presentation layer free of both.
///
/// It is deliberately a single pending route rather than a queue. Two alerts tapped before the hub
/// reacts should land on the second one, not walk through both.
@MainActor final class HubNavigator: ObservableObject {
    @Published private(set) var requested: HubRoute?

    func request(_ route: HubRoute) { requested = route }

    /// Called once the hub has navigated, so returning to the hub by hand does not bounce straight
    /// back into the feature.
    func clear() { requested = nil }
}
