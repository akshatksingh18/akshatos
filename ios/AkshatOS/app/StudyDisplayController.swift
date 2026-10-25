import SwiftUI
import UIKit

/// A foreground display preference, independent of the persisted study clock. Never changes a block.
@MainActor final class StudyDisplayController: ObservableObject {
    private let readIdleTimer: () -> Bool
    private let writeIdleTimer: (Bool) -> Void
    private var previousIdleTimer: Bool?

    init(readIdleTimer: @escaping () -> Bool = { UIApplication.shared.isIdleTimerDisabled },
         writeIdleTimer: @escaping (Bool) -> Void = { UIApplication.shared.isIdleTimerDisabled = $0 }) {
        self.readIdleTimer = readIdleTimer
        self.writeIdleTimer = writeIdleTimer
    }

    func update(visible: Bool, active: Bool, running: Bool, enabled: Bool) {
        if visible && active && running && enabled {
            if previousIdleTimer == nil { previousIdleTimer = readIdleTimer() }
            writeIdleTimer(true)
        } else { release() }
    }

    func release() {
        guard let previousIdleTimer else { return }
        self.previousIdleTimer = nil
        writeIdleTimer(previousIdleTimer)
    }
}
