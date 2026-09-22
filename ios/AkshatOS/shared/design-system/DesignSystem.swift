import SwiftUI

enum Palette {
    static let background = Color(red: 0.025, green: 0.035, blue: 0.075)
    static let card = Color(red: 0.075, green: 0.09, blue: 0.16)
    static let raised = Color(red: 0.105, green: 0.12, blue: 0.21)
    static let lime = Color(red: 0.76, green: 0.97, blue: 0.43)
    static let aqua = Color(red: 0.30, green: 0.91, blue: 0.93)
    static let violet = Color(red: 0.67, green: 0.49, blue: 1.00)
    static let coral = Color(red: 1.00, green: 0.43, blue: 0.55)
    static let gold = Color(red: 1.00, green: 0.78, blue: 0.32)
    static let muted = Color(red: 0.68, green: 0.72, blue: 0.82)

    static let cardGradient = LinearGradient(
        colors: [raised.opacity(0.96), card.opacity(0.96)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// A shared atmospheric background keeps every module in the same little universe without making
/// feature screens share business state. The shapes are decorative and deliberately motionless.
struct AppBackdrop: View {
    var body: some View {
        ZStack {
            Palette.background
            Circle()
                .fill(Palette.violet.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: 150, y: -320)
            Circle()
                .fill(Palette.aqua.opacity(0.10))
                .frame(width: 280, height: 280)
                .blur(radius: 75)
                .offset(x: -170, y: 310)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(Palette.cardGradient, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(contrast == .increased ? 0.38 : 0.09)))
            .shadow(color: .black.opacity(0.18), radius: 20, y: 12)
    }
}

struct AccentSurface<Content: View>: View {
    let accent: Color
    @ViewBuilder var content: Content
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(
                LinearGradient(colors: [accent.opacity(0.23), Palette.raised.opacity(0.98), Palette.card],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Circle().fill(accent.opacity(0.12)).frame(width: 120, height: 120)
                    .offset(x: 38, y: -48).accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(accent.opacity(contrast == .increased ? 0.65 : 0.28)))
            .shadow(color: accent.opacity(0.12), radius: 26, y: 12)
    }
}

struct QuestBadge: View {
    let text: String
    var icon = "sparkles"
    var accent = Palette.lime

    var body: some View {
        Label(text.uppercased(), systemImage: icon)
            .font(.caption2.weight(.black))
            .tracking(1.6)
            .foregroundStyle(accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(accent.opacity(0.24)))
    }
}

struct ProgressOrbit: View {
    let progress: Double
    let value: String
    let caption: String
    var accent = Palette.lime
    var systemImage = "bolt.fill"

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(AngularGradient(colors: [accent.opacity(0.55), accent], center: .center),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Image(systemName: systemImage).font(.caption.bold()).foregroundStyle(accent)
                Text(value).font(.system(.title2, design: .rounded, weight: .black)).monospacedDigit()
                Text(caption).font(.caption2.weight(.semibold)).foregroundStyle(Palette.muted)
            }
        }
        .frame(width: 116, height: 116)
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
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(primary ? Palette.background : Color.white)
            .background(primary ? Palette.lime : Palette.raised,
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(primary ? Palette.lime.opacity(0.2) : Color.white.opacity(0.08)))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.7 : 1))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
