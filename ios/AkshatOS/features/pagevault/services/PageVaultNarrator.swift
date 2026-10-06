import AVFoundation
import MediaPlayer
import PDFKit

/// Reads a book aloud with the phone's own voice, from a page onward.
///
/// Each page is handed to the voice as one continuous passage, and a sentence that runs over a
/// page break is spoken whole with the next page, so the voice keeps a natural flow instead of
/// starting afresh at every sentence. The voice reports its progress, which moves the tint.
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
        static let voiceTip = "pagevault.readAloud.voiceTipShown"
        static let shownVoices = "pagevault.readAloud.shownVoices"
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
    /// Nil follows the highest-quality voice across the phone's language variants.
    @Published var voiceID: String? {
        didSet {
            defaults.set(voiceID, forKey: Keys.voice)
            restartSentence()
        }
    }

    /// The voices Akshat chose to list in the speed menu, or nil until he chooses (the menu then
    /// lists the Enhanced and Premium ones). Removing the voice in use falls back to Best available.
    @Published private(set) var shownVoiceIDs: Set<String>?

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
    /// The sentence being spoken, or -1 while speaking words carried over from the previous page.
    private var index = 0
    /// The passage being spoken and where each sentence starts in it.
    private var plan: PageVaultSpeechPlan?
    /// Words from the previous page's unfinished last sentence that open the current passage.
    private var carriedIn: String?
    /// What was last handed to the voice. Read by tests; the voice itself cannot be heard there.
    private(set) var speaking = ""
    /// The one utterance whose end should move reading on. Anything else finishing — a passage
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
        shownVoiceIDs = (defaults.array(forKey: Keys.shownVoices) as? [String]).map(Set.init)
        // The synthesizer belongs to this reader alone, not the process; see check-boundaries.py.
        synthesizer.delegate = relay
        relay.finished = { [weak self] utterance in
            Task { @MainActor in self?.finished(utterance) }
        }
        relay.reached = { [weak self] location, utterance in
            Task { @MainActor in self?.reached(location, in: utterance) }
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
        suggestBetterVoiceOnce()
        speak(from: 0, carryIn: nil)
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
        carriedIn = nil
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
        state = .playing
        if index < 0 {
            // In the words carried over the page break: forward is this page's first sentence, back
            // is the sentence before the one that ran over.
            if step < 0, loadLastReadable(before: page) {
                onPageTurn?(page)
                speak(from: max(0, segments.count - 2), carryIn: nil)
            } else {
                speak(from: 0, carryIn: nil)
            }
            return
        }
        let target = index + step
        if target < 0 {
            guard loadLastReadable(before: page) else { speak(from: 0, carryIn: nil); return }
            onPageTurn?(page)
            speak(from: segments.count - 1, carryIn: nil)
        } else if target >= segments.count {
            guard loadFirstReadable(from: page + 1) else { finish(); return }
            onPageTurn?(page)
            speak(from: 0, carryIn: nil)
        } else {
            speak(from: target, carryIn: nil)
        }
    }

    func stop() {
        cancelSpeech()
        state = .stopped
        segment = nil
        plan = nil
        carriedIn = nil
        index = 0
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

    static func option(_ voice: AVSpeechSynthesisVoice) -> PageVaultReadAloud.VoiceOption {
        PageVaultReadAloud.VoiceOption(id: voice.identifier, name: voice.name, language: voice.language,
                                       quality: voice.quality.rawValue)
    }

    /// Every installed voice the Choose voices screen offers.
    static func voiceOptions() -> [PageVaultReadAloud.VoiceOption] { voices().map(option) }

    /// The short list in the speed menu.
    var menuVoices: [PageVaultReadAloud.VoiceOption] {
        PageVaultReadAloud.menuVoices(Self.voiceOptions(), shown: shownVoiceIDs, selected: voiceID)
    }

    func isShown(_ id: String) -> Bool {
        menuVoices.contains { $0.id == id }
    }

    /// Adds a voice to the speed menu or takes it off. The first change starts from what the menu
    /// was showing, so the Enhanced and Premium voices it listed are kept unless removed.
    func setShown(_ id: String, _ shown: Bool) {
        var ids = Set(menuVoices.map(\.id))
        if shown { ids.insert(id) } else { ids.remove(id) }
        shownVoiceIDs = ids
        defaults.set(Array(ids).sorted(), forKey: Keys.shownVoices)
        if !shown, voiceID == id { voiceID = nil }
    }

    private var voice: AVSpeechSynthesisVoice? {
        if let voiceID, let chosen = AVSpeechSynthesisVoice(identifier: voiceID) { return chosen }
        let code = AVSpeechSynthesisVoice.currentLanguageCode()
        return PageVaultReadAloud.bestVoice(in: Self.voices(), languageCode: code,
                                           quality: { $0.quality.rawValue }, language: { $0.language })
    }

    // MARK: - Reading

    /// Says the passage from the sentence reading has reached, as after a pause that could not be
    /// continued, or a speed or voice change.
    private func speakCurrent() {
        speak(from: max(0, index), carryIn: index < 0 ? carriedIn : nil)
    }

    /// Hands the voice the rest of this page from `start` as one passage. A last sentence that
    /// does not end on this page is held back and spoken with the next page.
    private func speak(from start: Int, carryIn: String?) {
        let hasNext = nextReadablePage(after: page) != nil
        let made = PageVaultReadAloud.plan(segments: segments, from: start, carryIn: carryIn,
                                           holdOpenTail: hasNext)
        guard !made.text.isEmpty else {
            // Only the unfinished last sentence was left: it belongs to the next page's passage.
            moveOn(carry: made.carry)
            return
        }
        plan = made
        carriedIn = carryIn
        let first = made.starts.first?.segment
        index = first ?? -1
        setSegment(first.map { segments[$0] })
        speaking = made.text
        let utterance = AVSpeechUtterance(string: made.text)
        utterance.voice = voice
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate,
                             max(AVSpeechUtteranceMinimumSpeechRate,
                                 AVSpeechUtteranceDefaultSpeechRate * Float(speed)))
        current = utterance
        state = .playing
        synthesizer.speak(utterance)
        updateNowPlaying()
    }

    /// Turns to the next page with text and reads on, opening with any words carried over.
    private func moveOn(carry: String?) {
        guard loadFirstReadable(from: page + 1) else { finish(); return }
        onPageTurn?(page)
        speak(from: 0, carryIn: carry)
    }

    private func finished(_ utterance: AVSpeechUtterance) {
        guard utterance === current, state == .playing else { return }
        current = nil
        moveOn(carry: plan?.carry)
    }

    /// The voice has reached a position in the passage: the tint follows to that sentence.
    private func reached(_ location: Int, in utterance: AVSpeechUtterance) {
        guard utterance === current, let start = plan?.start(atUTF16: location) else { return }
        let reachedIndex = start.segment ?? -1
        guard reachedIndex != index else { return }
        index = reachedIndex
        setSegment(start.segment.flatMap { $0 < segments.count ? segments[$0] : nil })
    }

    private func setSegment(_ value: PageVaultSpeechSegment?) {
        if segment != value { segment = value }
    }

    /// The basic voice every iPhone starts with sounds robotic. Said once: where the natural ones are.
    private func suggestBetterVoiceOnce() {
        guard !defaults.bool(forKey: Keys.voiceTip),
              !Self.voices().contains(where: { $0.quality != .default }) else { return }
        defaults.set(true, forKey: Keys.voiceTip)
        notice = "This phone only has the basic voice, which sounds robotic. For a natural voice, download a free Enhanced or Premium one in Settings → Accessibility → Spoken Content → Voices → English, then pick it from the speed menu here."
    }

    /// Starts again from the sentence being read, as after a speed or voice change.
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

    private func nextReadablePage(after start: Int) -> Int? {
        var candidate = start + 1
        while candidate < pageCount {
            if !sentences(on: candidate).isEmpty { return candidate }
            candidate += 1
        }
        return nil
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
    var reached: ((Int, AVSpeechUtterance) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        finished?(utterance)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        reached?(characterRange.location, utterance)
    }
}
