import AVFoundation
import MediaPlayer
import PDFKit

/// Reads a book aloud with the phone's own voice, from a page onward, one sentence at a time.
///
/// It turns pages as it goes, keeps going with the screen locked, and answers the lock screen,
/// Control Center and headphone buttons while it is reading. It never moves the book's place: only
/// the bookmark does that, as everywhere else in the reader. Everything stays on the phone.
@MainActor final class PageVaultNarrator: ObservableObject {
    enum State: Equatable { case stopped, playing, paused }

    static let speeds: [Double] = [0.75, 1, 1.25, 1.5, 1.75, 2]
    private enum Keys {
        static let speed = "pagevault.readAloud.speed"
        static let voice = "pagevault.readAloud.voice"
    }

    @Published private(set) var state: State = .stopped
    /// The sentence being read, which the reader tints.
    @Published private(set) var segment: PageVaultSpeechSegment?
    /// The page being read.
    @Published private(set) var page = 0
    @Published private(set) var notice: String?
    @Published var speed: Double {
        didSet {
            defaults.set(speed, forKey: Keys.speed)
            restartSentence()
        }
    }
    /// Nil follows the best voice installed for the phone's language.
    @Published var voiceID: String? {
        didSet {
            defaults.set(voiceID, forKey: Keys.voice)
            restartSentence()
        }
    }

    /// Asked to show a page when reading moves onto it.
    var onPageTurn: ((Int) -> Void)?

    private let url: URL
    private let title: String
    private let pageCount: Int
    private let defaults: UserDefaults
    private let synthesizer = AVSpeechSynthesizer()
    private let relay = PageVaultSpeechRelay()
    private var document: PDFDocument?
    private var texts: [Int: String] = [:]
    private var segments: [PageVaultSpeechSegment] = []
    private var index = 0
    /// The one utterance whose end should move reading on. Anything else finishing — a sentence
    /// cut short by skip, stop or a speed change — is ignored.
    private var current: AVSpeechUtterance?
    private var commands: [(MPRemoteCommand, Any)] = []
    private var interruption: NSObjectProtocol?

    init(url: URL, title: String, pageCount: Int, defaults: UserDefaults = .standard) {
        self.url = url
        self.title = title
        self.pageCount = pageCount
        self.defaults = defaults
        let saved = defaults.double(forKey: Keys.speed)
        speed = Self.speeds.contains(saved) ? saved : 1
        voiceID = defaults.string(forKey: Keys.voice)
        // The synthesizer belongs to this reader alone, not the process; see check-boundaries.py.
        synthesizer.delegate = relay
        relay.finished = { [weak self] utterance in
            Task { @MainActor in self?.finished(utterance) }
        }
    }

    // MARK: - Controls

    /// Starts reading at the top of `page`, or the next page with text after it.
    func play(from page: Int) {
        cancelSpeech()
        guard loadFirstReadable(from: page) else {
            stop()
            notice = page == 0
                ? "This book has no text to read aloud."
                : "There is no more text to read from this page on."
            return
        }
        index = 0
        // A page with no text (a blank or a full-page picture) is passed over; show where reading
        // actually starts.
        if self.page != page { onPageTurn?(self.page) }
        begin()
        speakCurrent()
    }

    /// The reader was turned by hand: reading moves to that page, still playing or still paused.
    func follow(page target: Int) {
        guard state != .stopped, target != page else { return }
        if state == .playing {
            play(from: target)
            return
        }
        cancelSpeech()
        guard loadFirstReadable(from: target) else { return }
        index = 0
        segment = segments.first
        if page != target { onPageTurn?(page) }
        updateNowPlaying()
    }

    func pause() {
        guard state == .playing else { return }
        synthesizer.pauseSpeaking(at: .word)
        state = .paused
        updateNowPlaying()
    }

    func resume() {
        guard state == .paused else { return }
        state = .playing
        begin()
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speakCurrent()
        }
        updateNowPlaying()
    }

    func toggle() { state == .playing ? pause() : resume() }

    /// Moves one sentence forward or back, across pages when needed, and keeps reading.
    func skip(_ step: Int) {
        guard state != .stopped else { return }
        cancelSpeech()
        let target = index + step
        if target < 0 {
            guard loadLastReadable(before: page) else { index = 0; speakCurrent(); return }
            index = segments.count - 1
            onPageTurn?(page)
        } else if target >= segments.count {
            guard loadFirstReadable(from: page + 1) else { finish(); return }
            index = 0
            onPageTurn?(page)
        } else {
            index = target
        }
        state = .playing
        speakCurrent()
    }

    func stop() {
        cancelSpeech()
        state = .stopped
        segment = nil
        end()
    }

    func clearNotice() { notice = nil }

    // MARK: - Voices

    /// Installed voices for the phone's language, best quality first. Novelty and personal voices
    /// are left out.
    static func voices() -> [AVSpeechSynthesisVoice] {
        let language = String(AVSpeechSynthesisVoice.currentLanguageCode().prefix(2))
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) }
            .filter { !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice) }
            .sorted {
                if $0.quality.rawValue != $1.quality.rawValue { return $0.quality.rawValue > $1.quality.rawValue }
                return $0.name < $1.name
            }
    }

    static func qualityLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Default"
        }
    }

    private var voice: AVSpeechSynthesisVoice? {
        if let voiceID, let chosen = AVSpeechSynthesisVoice(identifier: voiceID) { return chosen }
        let code = AVSpeechSynthesisVoice.currentLanguageCode()
        let all = Self.voices()
        return all.first { $0.language == code } ?? all.first
    }

    // MARK: - Reading

    private func speakCurrent() {
        guard index < segments.count else {
            guard loadFirstReadable(from: page + 1) else { finish(); return }
            index = 0
            onPageTurn?(page)
            speakCurrent()
            return
        }
        let next = segments[index]
        segment = next
        let utterance = AVSpeechUtterance(string: next.spoken)
        utterance.voice = voice
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate,
                             max(AVSpeechUtteranceMinimumSpeechRate,
                                 AVSpeechUtteranceDefaultSpeechRate * Float(speed)))
        current = utterance
        state = .playing
        synthesizer.speak(utterance)
        updateNowPlaying()
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard utterance === current, state == .playing else { return }
        current = nil
        index += 1
        speakCurrent()
    }

    /// Says the current sentence again from its start, as after a speed or voice change.
    private func restartSentence() {
        guard state == .playing else { return }
        cancelSpeech()
        speakCurrent()
    }

    private func cancelSpeech() {
        current = nil
        if synthesizer.isSpeaking || synthesizer.isPaused { synthesizer.stopSpeaking(at: .immediate) }
    }

    private func finish() {
        stop()
        notice = "Reached the end of the book."
    }

    // MARK: - Pages

    private func text(of page: Int) -> String {
        if let cached = texts[page] { return cached }
        if document == nil { document = PDFDocument(url: url) }
        let value = document?.page(at: page)?.string ?? ""
        texts[page] = value
        // Only the pages around the one being read are worth keeping.
        if texts.count > 12 {
            for key in texts.keys where abs(key - page) > PageVaultReadAloud.neighbourReach + 2 {
                texts[key] = nil
            }
        }
        return value
    }

    private func sentences(on page: Int) -> [PageVaultSpeechSegment] {
        let reach = PageVaultReadAloud.neighbourReach
        let neighbours = (max(0, page - reach)...min(pageCount - 1, page + reach))
            .filter { $0 != page }
            .map { PageVaultReadAloud.edgeKeys(text(of: $0)) }
        return PageVaultReadAloud.segments(page: page, text: text(of: page), neighbours: neighbours)
    }

    private func loadFirstReadable(from start: Int) -> Bool {
        guard start >= 0 else { return false }
        var candidate = start
        while candidate < pageCount {
            let found = sentences(on: candidate)
            if !found.isEmpty {
                page = candidate
                segments = found
                return true
            }
            candidate += 1
        }
        return false
    }

    private func loadLastReadable(before end: Int) -> Bool {
        var candidate = end - 1
        while candidate >= 0 {
            let found = sentences(on: candidate)
            if !found.isEmpty {
                page = candidate
                segments = found
                return true
            }
            candidate -= 1
        }
        return false
    }

    // MARK: - Audio session, lock screen and headphones

    /// Spoken audio that keeps playing with the screen locked, and the system controls with it.
    private func begin() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        guard commands.isEmpty else { return }
        let center = MPRemoteCommandCenter.shared()
        func on(_ command: MPRemoteCommand, _ action: @escaping @MainActor (PageVaultNarrator) -> Void) {
            command.isEnabled = true
            let target = command.addTarget { [weak self] _ in
                Task { @MainActor in if let self { action(self) } }
                return .success
            }
            commands.append((command, target))
        }
        on(center.playCommand) { $0.resume() }
        on(center.pauseCommand) { $0.pause() }
        on(center.togglePlayPauseCommand) { $0.toggle() }
        on(center.nextTrackCommand) { $0.skip(1) }
        on(center.previousTrackCommand) { $0.skip(-1) }

        // A call or another app's audio pauses reading; it picks up again only if iOS says so.
        interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            let info = note.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map(AVAudioSession.InterruptionOptions.init(rawValue:)) ?? []
            Task { @MainActor in
                guard let self else { return }
                if type == .began { self.pause() }
                if type == .ended, options.contains(.shouldResume) { self.resume() }
            }
        }
    }

    private func end() {
        for (command, target) in commands { command.removeTarget(target) }
        commands.removeAll()
        if let interruption { NotificationCenter.default.removeObserver(interruption) }
        interruption = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func updateNowPlaying() {
        guard state != .stopped else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: "PageVault · page \(page + 1) of \(pageCount)",
            MPNowPlayingInfoPropertyPlaybackRate: state == .playing ? 1.0 : 0.0
        ]
    }
}

/// Hears when a sentence has been spoken. A separate object because the narrator is main-actor
/// state and the synthesizer's callbacks are not formally isolated.
final class PageVaultSpeechRelay: NSObject, AVSpeechSynthesizerDelegate {
    var finished: ((AVSpeechUtterance) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished?(utterance)
    }
}
