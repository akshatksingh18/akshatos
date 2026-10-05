import AVFoundation
import SwiftUI

/// Which voices the speed menu lists. Every English voice on the iPhone is here, best first; a
/// tick puts it in the menu, and the speaker plays a short sample so you can hear it first. An app
/// cannot download or delete voices on the phone; that stays in iOS Settings.
struct PageVaultVoicesView: View {
    @ObservedObject var narrator: PageVaultNarrator
    @Environment(\.dismiss) private var dismiss
    /// Plays the samples; separate from the narrator so a sample never moves the reading.
    @State private var sampler = AVSpeechSynthesizer()

    var body: some View {
        let all = PageVaultNarrator.voiceOptions()
        NavigationStack {
            List {
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
        .onDisappear { sampler.stopSpeaking(at: .immediate) }
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
