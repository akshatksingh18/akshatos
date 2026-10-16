import SwiftUI
import UniformTypeIdentifiers

enum HubInk {
    static let background = Color(red: 0.098, green: 0.106, blue: 0.102)
    static let surface = Color(red: 0.141, green: 0.157, blue: 0.133)
    static let copper = Color(red: 0.898, green: 0.678, blue: 0.525)
    static let sage = Color(red: 0.663, green: 0.714, blue: 0.631)
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
        scrollContentBackground(.hidden).background(HubInk.background).tint(HubInk.copper)
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
            RoundedRectangle(cornerRadius: 5).fill(HubInk.sage.opacity(0.25)).offset(x: 5, y: 4)
            RoundedRectangle(cornerRadius: 5).fill(HubInk.copper.opacity(0.45))
            RoundedRectangle(cornerRadius: 24).stroke(HubInk.copper.opacity(0.7)).padding(10)
            Image(systemName: symbol).font(.title3).foregroundStyle(.white)
        }.frame(width: 54, height: 72).padding(.trailing, 8).accessibilityHidden(true)
    }
}
