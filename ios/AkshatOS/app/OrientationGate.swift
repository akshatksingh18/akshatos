import SwiftUI
import UIKit

/// The hub, library, and Squats dashboard stay portrait; only an open PDF reader may rotate.
/// UIKit asks the app delegate for supported orientations, so the decision lives at app scope and
/// features merely report whether a reading session is on screen.
@MainActor final class OrientationGate: ObservableObject {
    @Published private(set) var allowsLandscape = false

    func setReadingSession(_ active: Bool) {
        guard allowsLandscape != active else { return }
        allowsLandscape = active
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        let orientations: UIInterfaceOrientationMask =
            active ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    var supportedOrientations: UIInterfaceOrientationMask {
        allowsLandscape ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }
}
