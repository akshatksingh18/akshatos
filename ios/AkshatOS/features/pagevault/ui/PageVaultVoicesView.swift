import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// Which voices the speed menu offers. At the top, the natural voice: a Kokoro model imported once
/// from Files, with a speed test, then its speakers. Below, every English iPhone voice, best first.
/// For both, a tick puts the voice in the speed menu and the speaker button plays a short sample;
/// which one reads is picked in the speed menu. An app cannot download or delete iPhone voices;
/// that stays in iOS Settings.
struct PageVaultVoicesView: View {
    @ObservedObject var narrator: PageVaultNarrator
    @Environment(\.dismiss) private var dismiss
    /// Play the samples; separate from the narrator so a sample never moves the reading. Made on
    /// first use, because SwiftUI evaluates a state's starting value at every redraw.
    @State private var sampler: AVSpeechSynthesizer?
    @State private var naturalSampler: PageVaultNaturalSpeaker?
    /// Disk space the voice takes, measured off the main thread (it has hundreds of small files).
    @State private var naturalBytes: Int64?
    @State private var importingNatural = false
    @State private var naturalBusy: String?
    @State private var naturalResult: String?
    @State private var confirmingRemoval = false

    var body: some View {
        let all = PageVaultNarrator.voiceOptions()
        let shown = Set(narrator.menuVoices.map(\.id))
        NavigationStack {
            List {
                naturalSection
                if narrator.naturalInstalled { naturalSpeakers }
                section("Enhanced and Premium", all.filter { $0.quality > 1 }, all: all, shown: shown)
                section("Basic", all.filter { $0.quality <= 1 }, all: all, shown: shown)
                Section {
                } footer: {
                    Text("Ticked voices appear in the speed menu. To download or delete voices on this iPhone, go to Settings → Accessibility → Spoken Content → Voices → English; an app cannot do that.")
                }
            }
            .navigationTitle("Voices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .onDisappear {
            sampler?.stopSpeaking(at: .immediate)
            naturalSampler?.stop()
        }
        .task(id: narrator.naturalInstalled) {
            naturalBytes = nil
            guard narrator.naturalInstalled else { return }
            naturalBytes = await Task.detached(priority: .utility) {
                PageVaultNaturalVoice.shared.installedBytes
            }.value
        }
        .fileImporter(isPresented: $importingNatural, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            runNatural("Copying the voice\u{2026} this can take a minute.", importing: true) {
                try PageVaultNaturalVoice.shared.importVoice(from: url)
                return "Natural voice imported. Heart now reads; pick another speaker in the speed menu."
            }
        }
        .alert("Remove the natural voice?", isPresented: $confirmingRemoval) {
            Button("Remove", role: .destructive) {
                naturalSampler?.stop()
                PageVaultNaturalVoice.shared.remove()
                narrator.refreshNaturalInstalled()
                naturalResult = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is deleted from this iPhone. Import the folder again to bring it back.")
        }
    }

    /// The natural (neural) voice: import it, time it, remove it.
    @ViewBuilder
    private var naturalSection: some View {
        Section {
            if narrator.naturalInstalled {
                Button {
                    let speaker = narrator.naturalSpeaker
                    runNatural("Timing the voice\u{2026}") {
                        PageVaultNaturalVoice.shared.speedTest(speaker: speaker)
                    }
                } label: {
                    Label("Speed test", systemImage: "stopwatch")
                }
                .accessibilityIdentifier("natural-voice-speed-test")
                Button("Remove natural voice", role: .destructive) { confirmingRemoval = true }
            } else {
                Button {
                    importingNatural = true
                } label: {
                    Label("Import voice folder\u{2026}", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("natural-voice-import")
            }
            if let naturalBusy {
                HStack { ProgressView(); Text(naturalBusy).font(.caption) }
            }
            if let naturalResult {
                Text(naturalResult).font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("natural-voice-result")
            }
        } header: {
            Text("Natural voice (test)")
        } footer: {
            if narrator.naturalInstalled {
                let size = naturalBytes.map { " \(ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)) used." } ?? ""
                Text("Kokoro, running on this iPhone.\(size) It uses more battery than the iPhone voices.")
            } else {
                Text("A far more natural voice that runs on this iPhone, offline. Pick the unpacked kokoro-int8-multi-lang-v1_0 folder (about 180 MB) in Files; it comes from the sherpa-onnx tts-models release.")
            }
        }
    }

    /// Kokoro's speakers, ticked into the speed menu like the iPhone voices, each with a sample.
    private var naturalSpeakers: some View {
        Section("Natural speakers") {
            ForEach(PageVaultNaturalVoiceRules.speakers) { speaker in
                let isShown = narrator.isNaturalShown(speaker.id)
                HStack {
                    Button {
                        narrator.setNaturalShown(speaker.id, !isShown)
                    } label: {
                        HStack {
                            Image(systemName: isShown ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isShown ? Palette.accent : Palette.muted)
                            Text(speaker.label).foregroundStyle(Color.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isShown ? .isSelected : [])
                    .accessibilityIdentifier("natural-speaker-\(speaker.id)")
                    Spacer()
                    Button { sampleNatural(speaker.id) } label: { Image(systemName: "speaker.wave.2") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Play a sample of \(speaker.name)")
                }
            }
        }
    }

    private func sampleNatural(_ id: Int) {
        if narrator.state == .playing { narrator.pause() }
        sampler?.stopSpeaking(at: .immediate)
        let speaker = naturalSampler ?? PageVaultNaturalSpeaker()
        naturalSampler = speaker
        speaker.speak([.init(text: "This is how this voice reads your book.", utf16: 0)], speaker: id, speed: 1)
    }

    /// Runs slow natural-voice work off the main thread, showing what it is doing and then its result.
    private func runNatural(_ busy: String, importing: Bool = false,
                            _ work: @escaping @Sendable () throws -> String) {
        naturalBusy = busy
        naturalResult = nil
        Task.detached(priority: .userInitiated) {
            let outcome: String
            var succeeded = true
            do { outcome = try work() } catch { outcome = error.localizedDescription; succeeded = false }
            let imported = importing && succeeded
            await MainActor.run {
                naturalBusy = nil
                naturalResult = outcome
                narrator.refreshNaturalInstalled(justImported: imported)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ voices: [PageVaultReadAloud.VoiceOption],
                         all: [PageVaultReadAloud.VoiceOption], shown: Set<String>) -> some View {
        if !voices.isEmpty {
            Section(title) {
                ForEach(voices, id: \.id) { voice in
                    let isShown = shown.contains(voice.id)
                    HStack {
                        Button {
                            narrator.setShown(voice.id, !isShown)
                        } label: {
                            HStack {
                                Image(systemName: isShown ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isShown ? Palette.accent : Palette.muted)
                                Text(PageVaultReadAloud.voiceLabel(voice, among: all))
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isShown ? .isSelected : [])
                        Spacer()
                        Button { sample(voice) } label: { Image(systemName: "speaker.wave.2") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Play a sample of \(voice.name)")
                    }
                }
            }
        }
    }

    private func sample(_ voice: PageVaultReadAloud.VoiceOption) {
        // The book pauses rather than talking over the sample; play resumes it.
        if narrator.state == .playing { narrator.pause() }
        naturalSampler?.stop()
        let synthesizer = sampler ?? AVSpeechSynthesizer()
        sampler = synthesizer
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "This is how this voice reads your book.")
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
        synthesizer.speak(utterance)
    }
}
