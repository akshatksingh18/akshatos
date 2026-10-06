import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

/// Which voices read. At the top, the natural voice: a Kokoro model imported once from Files, with
/// its speakers, a sample and a speed test. Below, every English iPhone voice, best first; a tick
/// puts it in the speed menu and the speaker plays a short sample. An app cannot download or delete
/// iPhone voices; that stays in iOS Settings.
struct PageVaultVoicesView: View {
    @ObservedObject var narrator: PageVaultNarrator
    @Environment(\.dismiss) private var dismiss
    /// Plays the samples; separate from the narrator so a sample never moves the reading.
    @State private var sampler = AVSpeechSynthesizer()
    @State private var naturalSampler = PageVaultNaturalSpeaker()
    @State private var importingNatural = false
    @State private var naturalBusy: String?
    @State private var naturalResult: String?
    @State private var naturalInstalled = PageVaultNaturalVoice.shared.isInstalled
    @State private var confirmingRemoval = false

    var body: some View {
        let all = PageVaultNarrator.voiceOptions()
        NavigationStack {
            List {
                naturalSection
                section("Enhanced and Premium", all.filter { $0.quality > 1 }, all: all)
                section("Basic", all.filter { $0.quality <= 1 }, all: all)
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
            sampler.stopSpeaking(at: .immediate)
            naturalSampler.stop()
        }
        .fileImporter(isPresented: $importingNatural, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            runNatural("Copying the voice\u{2026} this can take a minute.") {
                try PageVaultNaturalVoice.shared.importVoice(from: url)
                return "Natural voice imported."
            }
        }
        .alert("Remove the natural voice?", isPresented: $confirmingRemoval) {
            Button("Remove", role: .destructive) {
                narrator.naturalVoiceOn = false
                PageVaultNaturalVoice.shared.remove()
                naturalInstalled = false
                naturalResult = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It is deleted from this iPhone. Import the folder again to bring it back.")
        }
    }

    /// The natural (neural) voice: import it, choose a speaker, hear it and time it.
    @ViewBuilder
    private var naturalSection: some View {
        Section {
            if naturalInstalled {
                Toggle("Read with the natural voice", isOn: $narrator.naturalVoiceOn)
                    .accessibilityIdentifier("natural-voice-toggle")
                Picker("Speaker", selection: $narrator.naturalSpeaker) {
                    ForEach(PageVaultNaturalVoiceRules.speakers) { speaker in
                        Text(speaker.label).tag(speaker.id)
                    }
                }
                Button {
                    if narrator.state == .playing { narrator.pause() }
                    naturalSampler.speak([.init(text: "This is how this voice reads your book.", utf16: 0)],
                                         speaker: narrator.naturalSpeaker, speed: 1)
                } label: {
                    Label("Play a sample", systemImage: "speaker.wave.2")
                }
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
            if naturalInstalled {
                Text("Kokoro, running on this iPhone. \(ByteCountFormatter.string(fromByteCount: PageVaultNaturalVoice.shared.installedBytes, countStyle: .file)) used. It uses more battery than the iPhone voices.")
            } else {
                Text("A far more natural voice that runs on this iPhone, offline. Pick the unpacked kokoro-int8-multi-lang-v1_0 folder (about 180 MB) in Files; it comes from the sherpa-onnx tts-models release.")
            }
        }
    }

    /// Runs slow natural-voice work off the main thread, showing what it is doing and then its result.
    private func runNatural(_ busy: String, _ work: @escaping @Sendable () throws -> String) {
        naturalBusy = busy
        naturalResult = nil
        Task.detached(priority: .userInitiated) {
            let outcome: String
            do { outcome = try work() } catch { outcome = error.localizedDescription }
            await MainActor.run {
                naturalBusy = nil
                naturalResult = outcome
                naturalInstalled = PageVaultNaturalVoice.shared.isInstalled
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ voices: [PageVaultReadAloud.VoiceOption],
                         all: [PageVaultReadAloud.VoiceOption]) -> some View {
        if !voices.isEmpty {
            Section(title) {
                ForEach(voices, id: \.id) { voice in
                    HStack {
                        Button {
                            narrator.setShown(voice.id, !narrator.isShown(voice.id))
                        } label: {
                            HStack {
                                Image(systemName: narrator.isShown(voice.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(narrator.isShown(voice.id) ? Palette.accent : Palette.muted)
                                Text(PageVaultReadAloud.voiceLabel(voice, among: all))
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(narrator.isShown(voice.id) ? .isSelected : [])
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
        sampler.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: "This is how this voice reads your book.")
        utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
        sampler.speak(utterance)
    }
}
