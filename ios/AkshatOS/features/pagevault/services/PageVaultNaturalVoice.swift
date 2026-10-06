import AVFoundation
import Foundation
import SherpaOnnx

/// The natural voice: a Kokoro model Akshat imports once from Files, run on the phone by
/// sherpa-onnx. Nothing is downloaded by the app and nothing leaves the phone. The model is large
/// (about 180 MB unpacked), so it is loaded on first use and kept while the app runs.
///
/// Every engine call runs on one serial queue: the engine is not thread-safe, and rendering a
/// sentence takes long enough that it must stay off the main thread.
final class PageVaultNaturalVoice: @unchecked Sendable {
    static let shared = PageVaultNaturalVoice()

    enum Failure: LocalizedError {
        case missing([String])
        case copy(String)

        var errorDescription: String? {
            switch self {
            case .missing(let items):
                return "That folder is not a Kokoro voice: it has no \(items.joined(separator: ", ")). Pick the unpacked kokoro-int8-multi-lang-v1_0 folder."
            case .copy(let reason):
                return "The voice could not be copied: \(reason)"
            }
        }
    }

    /// Outside PageVault's own folder, which holds only books.
    let folder: URL
    private let queue = DispatchQueue(label: "pagevault.natural-voice", qos: .userInitiated)
    private var engine: SherpaOnnxOfflineTtsWrapper?

    init(folder: URL? = nil) {
        if let folder {
            self.folder = folder
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.folder = support.appendingPathComponent("PageVaultVoice", isDirectory: true)
        }
    }

    var isInstalled: Bool {
        PageVaultNaturalVoiceRules.missing(from: present(in: folder)).isEmpty
    }

    /// Disk space the installed voice takes.
    var installedBytes: Int64 {
        guard let walker = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var total: Int64 = 0
        for case let file as URL in walker {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }

    private func present(in directory: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? [])
    }

    // MARK: - Import and removal

    /// Copies a picked voice folder in, file by file through the file provider so a OneDrive or
    /// iCloud folder downloads as it copies. The old voice is replaced only once the new one is
    /// complete, and the copy is kept out of the phone's backup because it can be imported again.
    func importVoice(from source: URL) throws {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let missing = PageVaultNaturalVoiceRules.missing(from: present(in: source))
        guard missing.isEmpty else { throw Failure.missing(missing) }

        let fileManager = FileManager.default
        let staging = folder.deletingLastPathComponent()
            .appendingPathComponent("PageVaultVoice-incoming", isDirectory: true)
        try? fileManager.removeItem(at: staging)
        do {
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            // Relative paths, so a /private/var versus /var spelling of the same folder cannot matter.
            guard let walker = fileManager.enumerator(atPath: source.path) else {
                throw Failure.copy("the folder could not be read")
            }
            for case let relative as String in walker {
                let item = source.appendingPathComponent(relative)
                let target = staging.appendingPathComponent(relative)
                if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    try fileManager.createDirectory(at: target, withIntermediateDirectories: true)
                    continue
                }
                var failure: Error?
                var coordination: NSError?
                NSFileCoordinator().coordinate(readingItemAt: item, options: [], error: &coordination) { readable in
                    do { try fileManager.copyItem(at: readable, to: target) } catch { failure = error }
                }
                if let error = failure ?? coordination { throw Failure.copy(error.localizedDescription) }
            }
            queue.sync { engine = nil }
            try? fileManager.removeItem(at: folder)
            try fileManager.moveItem(at: staging, to: folder)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var excluded = folder
            try? excluded.setResourceValues(values)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    func remove() {
        queue.sync { engine = nil }
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: - Rendering

    /// Speech for `text` as 24 kHz mono samples, or nil when no voice is installed. Blocks the
    /// calling thread while the engine works, so call it off the main thread.
    func render(_ text: String, speaker: Int, speed: Float) -> [Float]? {
        queue.sync {
            guard let engine = loadedEngine() else { return nil }
            let audio = engine.generate(text: text, sid: speaker, speed: speed)
            return audio.samples
        }
    }

    /// Loads the model the first time it is needed. Only on `queue`.
    private func loadedEngine() -> SherpaOnnxOfflineTtsWrapper? {
        if let engine { return engine }
        let has = present(in: folder)
        guard isInstalled, let modelName = PageVaultNaturalVoiceRules.modelFile(in: has) else { return nil }
        let directory = folder.path
        let lexicons = ["lexicon-us-en.txt", "lexicon-gb-en.txt", "lexicon-zh.txt"]
            .filter { has.contains($0) }
            .map { "\(directory)/\($0)" }
            .joined(separator: ",")
        let kokoro = sherpaOnnxOfflineTtsKokoroModelConfig(
            model: "\(directory)/\(modelName)",
            voices: "\(directory)/voices.bin",
            tokens: "\(directory)/tokens.txt",
            dataDir: "\(directory)/espeak-ng-data",
            dictDir: has.contains("dict") ? "\(directory)/dict" : "",
            lexicon: lexicons)
        let model = sherpaOnnxOfflineTtsModelConfig(kokoro: kokoro, numThreads: 2)
        var config = sherpaOnnxOfflineTtsConfig(model: model)
        let loaded = SherpaOnnxOfflineTtsWrapper(config: &config)
        engine = loaded
        return loaded
    }

    /// Times the voice on a fixed passage: how long until the first sentence is ready, and how much
    /// faster than real time it renders overall. Read aloud needs comfortably more than 1×.
    func speedTest(speaker: Int) -> String {
        let sentences = [
            "Grit is passion and perseverance for very long-term goals.",
            "It means sticking with your future, day in, day out, not just for the week or the month, but for years.",
            "Enthusiasm is common; endurance is rare."
        ]
        let started = Date()
        var firstPiece = 0.0
        var samples = 0
        for (index, sentence) in sentences.enumerated() {
            guard let audio = render(sentence, speaker: speaker, speed: 1) else {
                return "No natural voice is installed."
            }
            samples += audio.count
            if index == 0 { firstPiece = Date().timeIntervalSince(started) }
        }
        return PageVaultNaturalVoiceRules.speedSummary(
            audio: PageVaultNaturalVoiceRules.seconds(ofSamples: samples),
            render: Date().timeIntervalSince(started), firstPiece: firstPiece)
    }
}

/// Plays a passage in the natural voice: renders its pieces a few ahead on a background thread and
/// plays them back to back, saying when each piece starts (so the tint can follow) and when the
/// last one ends. Any call to `speak` or `stop` makes earlier work stale, and stale work is dropped.
@MainActor final class PageVaultNaturalSpeaker {
    var reached: ((Int) -> Void)?
    var finished: (() -> Void)?
    private(set) var isSpeaking = false
    private(set) var isPaused = false

    private let voice: PageVaultNaturalVoice
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: PageVaultNaturalVoiceRules.sampleRate, channels: 1)!
    private var generation = 0
    private var pieces: [PageVaultNaturalVoiceRules.Piece] = []
    private var speaker = PageVaultNaturalVoiceRules.defaultSpeaker
    private var speed: Float = 1
    /// Pieces handed to the player and not yet finished playing.
    private var queued = 0
    private var nextToRender = 0
    private var playing = 0
    private var rendering = false

    init(voice: PageVaultNaturalVoice = .shared) {
        self.voice = voice
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func speak(_ pieces: [PageVaultNaturalVoiceRules.Piece], speaker: Int, speed: Float) {
        stop()
        guard !pieces.isEmpty else { finished?(); return }
        self.pieces = pieces
        self.speaker = speaker
        self.speed = speed
        isSpeaking = true
        startEngine()
        renderAhead()
    }

    func pause() {
        guard isSpeaking, !isPaused else { return }
        player.pause()
        isPaused = true
    }

    func resume() {
        guard isSpeaking, isPaused else { return }
        startEngine()
        isPaused = false
    }

    func stop() {
        generation += 1
        player.stop()
        pieces = []
        queued = 0
        nextToRender = 0
        playing = 0
        rendering = false
        isSpeaking = false
        isPaused = false
    }

    private func startEngine() {
        if !engine.isRunning { try? engine.start() }
        player.play()
    }

    /// Renders the next piece if it is within the lookahead, then schedules it.
    private func renderAhead() {
        guard isSpeaking, !rendering, nextToRender < pieces.count,
              nextToRender - playing < PageVaultNaturalVoiceRules.lookahead else { return }
        rendering = true
        let index = nextToRender
        let piece = pieces[index]
        let token = generation
        let voice = voice
        let speaker = speaker
        let speed = speed
        Task.detached(priority: .userInitiated) {
            let samples = voice.render(piece.text, speaker: speaker, speed: speed) ?? []
            await MainActor.run { self.rendered(samples, index: index, token: token) }
        }
    }

    private func rendered(_ samples: [Float], index: Int, token: Int) {
        guard token == generation else { return }
        rendering = false
        nextToRender = index + 1
        // A piece the engine could not voice still gets a moment of silence, so every piece plays
        // and the passage always reaches its end.
        if let buffer = makeBuffer(samples.isEmpty ? [Float](repeating: 0, count: 1_200) : samples) {
            if queued == 0 {
                playing = index
                reached?(pieces[index].utf16)
            }
            queued += 1
            player.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
                Task { @MainActor in self?.played(index: index, token: token) }
            }
            if !isPaused, !player.isPlaying { player.play() }
        }
        renderAhead()
    }

    private func played(index: Int, token: Int) {
        guard token == generation else { return }
        queued -= 1
        if index + 1 < pieces.count {
            playing = index + 1
            if index + 1 < nextToRender { reached?(pieces[index + 1].utf16) }
            renderAhead()
        } else {
            end()
        }
    }

    private func end() {
        isSpeaking = false
        isPaused = false
        finished?()
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard !samples.isEmpty,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        samples.withUnsafeBufferPointer { channel.update(from: $0.baseAddress!, count: samples.count) }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        return buffer
    }
}
