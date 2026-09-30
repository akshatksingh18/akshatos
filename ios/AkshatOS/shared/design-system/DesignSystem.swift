import SwiftUI

/// A quiet palette: near-black neutrals and one accent used sparingly for the thing that matters on
/// a screen. The earlier multi-colour "quest" theme was retired at Akshat's request in favour of a
/// clean, minimal look.
enum Palette {
    static let background = Color(red: 0.043, green: 0.043, blue: 0.051)
    static let card = Color(red: 0.086, green: 0.086, blue: 0.098)
    static let raised = Color(red: 0.125, green: 0.125, blue: 0.141)
    static let accent = Color(red: 0.52, green: 0.82, blue: 0.70)
    static let muted = Color(red: 0.60, green: 0.60, blue: 0.64)
}

/// The app background: one flat colour, nothing drawn on it.
struct AppBackdrop: View {
    var body: some View {
        Palette.background
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A flat card with a hairline edge.
struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(contrast == .increased ? 0.32 : 0.06)))
    }
}

/// A thin progress ring with the number in the middle.
struct ProgressOrbit: View {
    let progress: Double
    let value: String
    let caption: String

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(value).font(.title.weight(.semibold)).monospacedDigit()
                Text(caption).font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityElement(children: .combine)
    }
}

/// A label/value row that lays out side-by-side normally, but stacks vertically at accessibility
/// Dynamic Type sizes so neither side is squeezed or clipped by a fixed-width `HStack` + `Spacer`.
struct AdaptiveRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var spacing: CGFloat = 8
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) { leading; trailing }
        } else {
            HStack(spacing: spacing) { leading; Spacer(); trailing }
        }
    }
}

struct ActionStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .foregroundStyle(primary ? Palette.background : Color.white)
            .background(primary ? Palette.accent : Palette.raised,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.7 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
