import CoreGraphics
import SwiftUI
import UniformTypeIdentifiers

/// The personal hub's ink. The ground is warm rather than neutral, and the accent is a cool violet,
/// so a mark separates from the surface it sits on. The three `series` values are the only colours
/// allowed to encode categories in a chart: they are validated together against `surface` for
/// lightness, chroma, adjacent separation in normal vision and under simulated colour blindness.
/// `accent` is deliberately brighter than any of them because it is never a chart series, only a
/// lone mark. Pair a series with words, never colour alone.
enum HubInk {
    static let background = Color(red: 0.063, green: 0.047, blue: 0.035)
    static let surface = Color(red: 0.157, green: 0.122, blue: 0.102)
    static let accent = Color(red: 0.663, green: 0.545, blue: 1.000)
    static let support = Color(red: 0.357, green: 0.753, blue: 0.561)
    static let seriesRecorded = Color(red: 0.431, green: 0.310, blue: 0.839)
    static let seriesAboveUsual = Color(red: 0.165, green: 0.580, blue: 0.471)
    static let seriesBest = Color(red: 0.753, green: 0.416, blue: 0.227)
    static let lightAccent = Color(red: 0.533, green: 0.439, blue: 0.910)
    static let lightWarm = Color(red: 0.353, green: 0.235, blue: 0.157)
}

/// One tile of static monochrome noise, built once. It is the grain in the lit background; without
/// it the warm ground bands visibly where the two lights overlap.
private enum HubGrainTile {
    static let image: Image? = {
        let side = 96, bytesPerPixel = 4
        var bytes = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        var seed: UInt64 = 0x2545_F491_4F6C_DD1D
        for pixel in 0..<(side * side) {
            seed ^= seed << 13; seed ^= seed >> 7; seed ^= seed << 17
            let level = UInt8(truncatingIfNeeded: seed >> 24)
            let offset = pixel * bytesPerPixel
            bytes[offset] = level; bytes[offset + 1] = level; bytes[offset + 2] = level
            bytes[offset + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: side * bytesPerPixel, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return Image(decorative: image, scale: 1)
    }()
}

/// The hub's ground. `lit` adds the two lights and the grain; it is off wherever the screen stays on
/// for a long stretch, because those layers are the expensive part of this design. Purely decorative,
/// so it is hidden from assistive technology and never carries meaning on its own.
struct HubBackground: View {
    var lit = true
    var body: some View {
        ZStack {
            HubInk.background
            if lit {
                GeometryReader { proxy in
                    let span = max(proxy.size.width, proxy.size.height)
                    RadialGradient(colors: [HubInk.lightAccent.opacity(0.55), .clear],
                                   center: UnitPoint(x: 1.02, y: -0.04), startRadius: 0, endRadius: span * 0.9)
                    RadialGradient(colors: [HubInk.lightWarm.opacity(0.45), .clear],
                                   center: UnitPoint(x: -0.08, y: 1.02), startRadius: 0, endRadius: span * 0.75)
                    if let grain = HubGrainTile.image {
                        grain.resizable(resizingMode: .tile).blendMode(.overlay).opacity(0.05)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct PortableDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText, .plainText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct PersonalMessageAlert: ViewModifier {
    let title: String
    @Binding var message: String?
    func body(content: Content) -> some View {
        content.alert(title, isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }
}
extension View {
    func personalMessage(_ title: String, message: Binding<String?>) -> some View {
        modifier(PersonalMessageAlert(title: title, message: message))
    }
    func personalList() -> some View {
        scrollContentBackground(.hidden).background(HubInk.background).tint(HubInk.accent)
    }
}

struct ThoughtCaptureField: View {
    var save: (String) -> Bool
    @State private var text = ""
    @State private var saved = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Park a thought", text: $text, axis: .vertical)
                    .lineLimit(1...4).submitLabel(.done).onSubmit(capture)
                    .accessibilityIdentifier("thought-input")
                Button(action: capture) { Image(systemName: "plus.circle.fill").font(.title2).frame(minWidth: 44, minHeight: 44) }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save for after study").accessibilityIdentifier("save-thought")
            }
            if saved { Text("Saved in To-do → After study").font(.caption).foregroundStyle(.secondary).accessibilityAddTraits(.updatesFrequently) }
        }
    }
    private func capture() { if save(text) { text = ""; saved = true } }
}

struct HubBookArtwork: View {
    let symbol: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5).fill(HubInk.support.opacity(0.25)).offset(x: 5, y: 4)
            RoundedRectangle(cornerRadius: 5).fill(HubInk.accent.opacity(0.45))
            RoundedRectangle(cornerRadius: 24).stroke(HubInk.accent.opacity(0.7)).padding(10)
            Image(systemName: symbol).font(.title3).foregroundStyle(.white)
        }.frame(width: 54, height: 72).padding(.trailing, 8).accessibilityHidden(true)
    }
}
