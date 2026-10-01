import AVFoundation
import SwiftUI

/// The controls while a book is read aloud: back a sentence, play or pause, forward a sentence,
/// speed and voice, and stop. The lock screen and headphones offer the same through the system.
struct PageVaultReadAloudBar: View {
    @ObservedObject var narrator: PageVaultNarrator

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
    }

    /// Speed, and which installed voice reads. Better voices are a free download in iOS Settings.
    private var settings: some View {
        Menu {
            Picker("Speed", selection: $narrator.speed) {
                ForEach(PageVaultNarrator.speeds, id: \.self) { speed in
                    Text(Self.speedLabel(speed)).tag(speed)
                }
            }
            Picker("Voice", selection: $narrator.voiceID) {
                Text("Best available").tag(String?.none)
                ForEach(PageVaultNarrator.voices(), id: \.identifier) { voice in
                    Text("\(voice.name) · \(PageVaultNarrator.qualityLabel(voice))").tag(Optional(voice.identifier))
                }
            }
            Text("Download Enhanced or Premium voices in Settings → Accessibility → Spoken Content → Voices.")
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
