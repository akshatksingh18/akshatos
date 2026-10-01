import AVFoundation
import SwiftUI

/// The few video players the feed keeps alive: the page on screen and its neighbours. Only the
/// page on screen plays and makes sound; the rest wait silently at their first frame, and anything
/// further away is let go, so a long library never holds a pile of players.
@MainActor final class ReelPlayerPool: ObservableObject {
    private struct Entry {
        let player: AVQueuePlayer
        /// Keeps the video looping until the page is swiped away.
        let looper: AVPlayerLooper
    }

    /// Bumped whenever the set of players changes, so pages pick up their player.
    @Published private(set) var revision = 0
    private var entries: [UUID: Entry] = [:]

    func player(for page: UUID) -> AVQueuePlayer? { entries[page]?.player }

    /// Makes sure exactly these pages have a player, creating and releasing as needed.
    func prepare(_ pages: [(page: UUID, url: URL)]) {
        let wanted = Set(pages.map(\.page))
        var changed = false
        for key in Array(entries.keys) where !wanted.contains(key) {
            entries[key]?.player.pause()
            entries[key]?.looper.disableLooping()
            entries[key] = nil
            changed = true
        }
        for (page, url) in pages where entries[page] == nil {
            let player = AVQueuePlayer()
            player.isMuted = true
            let looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            entries[page] = Entry(player: player, looper: looper)
            changed = true
        }
        if changed { revision += 1 }
    }

    /// Plays or pauses the page on screen, with sound, and silences and rewinds every other page.
    func show(_ page: UUID?, playing: Bool) {
        for (key, entry) in entries {
            if key == page {
                entry.player.isMuted = false
                if playing { entry.player.play() } else { entry.player.pause() }
            } else {
                entry.player.pause()
                entry.player.isMuted = true
                entry.player.seek(to: .zero)
            }
        }
    }

    /// A video viewer opened on purpose plays its sound even with the ring switch on silent; the
    /// volume buttons still apply.
    func activateAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    func releaseAll() {
        prepare([])
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// Shows a player's picture, fitted inside the page with no controls of its own.
struct ReelPlayerLayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> ReelPlayerSurface {
        let view = ReelPlayerSurface()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ view: ReelPlayerSurface, context: Context) {
        if view.playerLayer.player !== player { view.playerLayer.player = player }
    }
}

final class ReelPlayerSurface: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
