import SwiftUI

enum Palette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.085)
    static let card = Color(red: 0.085, green: 0.11, blue: 0.15)
    static let lime = Color(red: 0.76, green: 0.97, blue: 0.43)
    static let muted = Color(red: 0.65, green: 0.70, blue: 0.77)
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorSchemeContrast) private var contrast
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26)
                .stroke(.white.opacity(contrast == .increased ? 0.35 : 0.06)))
    }
}

struct ActionStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity).padding(.vertical, 17)
            .foregroundStyle(primary ? Palette.background : Color.white)
            .background(primary ? Palette.lime : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 18))
            .opacity(!isEnabled ? 0.4 : (configuration.isPressed ? 0.7 : 1))
    }
}
