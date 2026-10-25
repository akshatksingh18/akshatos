import SwiftUI
import UIKit

/// The hub stays portrait; the PDF reader and study Focus may rotate independently.
/// UIKit asks the app delegate for supported orientations, so the decision lives at app scope and
/// features merely report whether a reading session is on screen.
@MainActor final class OrientationGate: ObservableObject {
    @Published private(set) var allowsLandscape = false
    private var reading = false
    private var studyFocus = false

    func setReadingSession(_ active: Bool) {
        reading = active
        update()
    }

    func setStudyFocusSession(_ active: Bool) {
        studyFocus = active
        update()
    }

    private func update() {
        let active = reading || studyFocus
        guard allowsLandscape != active else { return }
        allowsLandscape = active
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first else { return }
        let orientations: UIInterfaceOrientationMask =
            active ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
        var controller = scene.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController { controller = presented }
        controller?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
    }

    var supportedOrientations: UIInterfaceOrientationMask {
        allowsLandscape ? [.portrait, .landscapeLeft, .landscapeRight] : .portrait
    }
}
