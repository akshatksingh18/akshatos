import AVFoundation
import SwiftUI

/// The controls while a book is read aloud: back a sentence, play or pause, forward a sentence,
/// speed and voice, and stop. The lock screen and headphones offer the same through the system.
struct PageVaultReadAloudBar: View {
    @ObservedObject var narrator: PageVaultNarrator
    @State private var choosingVoices = false

    var body: some View {
        HStack(spacing: 22) {
            Button { narrator.skip(-1) } label: { Image(systemName: "backward.fill") }
                .accessibilityLabel("Previous sentence")
                .accessibilityIdentifier("read-aloud-back")
            Button { narrator.toggle() } label: {
                Image(systemName: narrator.state == .playing ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 28)
            }
            .accessibilityLabel(narrator.state == .playing ? "Pause" : "Resume")
            .accessibilityIdentifier("read-aloud-toggle")
            Button { narrator.skip(1) } label: { Image(systemName: "forward.fill") }
                .accessibilityLabel("Next sentence")
                .accessibilityIdentifier("read-aloud-forward")
            settings
            Button { narrator.stop() } label: { Image(systemName: "xmark") }
                .accessibilityLabel("Stop reading aloud")
                .accessibilityIdentifier("read-aloud-stop")
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.black.opacity(0.7), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("read-aloud-bar")
        .sheet(isPresented: $choosingVoices) { PageVaultVoicesView(narrator: narrator) }
    }

    /// Speed, and which voice reads: one list with one tick, the natural speakers Akshat chose first,
    /// then his chosen iPhone voices, with Choose voices to change those lists.
    private var settings: some View {
        Menu {
            Picker("Speed", selection: $narrator.speed) {
                ForEach(PageVaultNarrator.speeds, id: \.self) { speed in
                    Text(Self.speedLabel(speed)).tag(speed)
                }
            }
            Picker("Voice", selection: Binding(get: { narrator.voiceChoice },
                                               set: { narrator.choose($0) })) {
                ForEach(narrator.menuNaturalSpeakers) { speaker in
                    Text(PageVaultNaturalVoiceRules.menuLabel(speaker))
                        .tag(PageVaultReadAloud.VoiceChoice.natural(speaker.id))
                }
                let all = PageVaultNarrator.voiceOptions()
                ForEach(narrator.menuVoices, id: \.id) { voice in
                    Text(PageVaultReadAloud.voiceLabel(voice, among: all))
                        .tag(PageVaultReadAloud.VoiceChoice.system(voice.id))
                }
                Text("Best iPhone voice").tag(PageVaultReadAloud.VoiceChoice.system(nil))
            }
            .accessibilityIdentifier("read-aloud-voice")
            Button("Choose voices…") { choosingVoices = true }
                .accessibilityIdentifier("read-aloud-choose-voices")
        } label: {
            Text(Self.speedLabel(narrator.speed))
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        .accessibilityLabel("Speed and voice")
        .accessibilityIdentifier("read-aloud-speed")
    }

    static func speedLabel(_ speed: Double) -> String {
        let text = speed == speed.rounded() ? String(Int(speed)) : String(speed)
        return "\(text)×"
    }
}
