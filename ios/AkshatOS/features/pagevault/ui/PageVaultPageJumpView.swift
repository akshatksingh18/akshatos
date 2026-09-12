import SwiftUI

/// Going to a page directly, reached by tapping the reader's page indicator.
///
/// Both a slider and a typed number, because neither alone is enough in a long book: dragging is
/// how you land somewhere roughly right without knowing the number, and typing is the only way to
/// reach an exact page when one screen pixel covers several of them.
struct PageVaultPageJumpView: View {
    let pageCount: Int
    /// Zero-based, as pages are stored everywhere else.
    let currentPage: Int
    var onJump: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    /// One-based while it is on screen, because that is what the reader shows and what a book
    /// prints. Converted back on the way out.
    @State private var target: Double
    @State private var typed: String

    init(pageCount: Int, currentPage: Int, onJump: @escaping (Int) -> Void) {
        self.pageCount = pageCount
        self.currentPage = currentPage
        self.onJump = onJump
        let opening = min(max(currentPage + 1, 1), max(pageCount, 1))
        _target = State(initialValue: Double(opening))
        _typed = State(initialValue: String(opening))
    }

    private var page: Int { min(max(Int(target.rounded()), 1), max(pageCount, 1)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 26) {
                VStack(spacing: 6) {
                    Text("\(page)")
                        .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                        .accessibilityIdentifier("jump-target-page")
                    Text("of \(pageCount)")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Page \(page) of \(pageCount)")

                // A one-page document has nothing to slide along, and a 1...1 range is not a valid
                // slider.
                if pageCount > 1 {
                    Slider(value: $target, in: 1...Double(pageCount), step: 1) {
                        Text("Page")
                    } minimumValueLabel: {
                        Text("1").font(.caption2).foregroundStyle(Palette.muted)
                    } maximumValueLabel: {
                        Text("\(pageCount)").font(.caption2).foregroundStyle(Palette.muted)
                    }
                    .tint(Palette.lime)
                    .accessibilityIdentifier("jump-slider")
                    .onChange(of: target) { _, value in
                        let settled = min(max(Int(value.rounded()), 1), pageCount)
                        if typed != String(settled) { typed = String(settled) }
                    }
                }

                HStack(spacing: 12) {
                    Text("Go to page").font(.subheadline)
                    TextField("Page", text: $typed)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.body.monospacedDigit())
                        .frame(width: 96)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("jump-page-field")
                        .onChange(of: typed) { _, value in
                            // Keep the slider and the field showing the same page, and refuse
                            // anything that is not a page in this book rather than jumping wrongly.
                            let digits = value.filter(\.isNumber)
                            if digits != value { typed = digits; return }
                            guard let entered = Int(digits), entered >= 1, entered <= pageCount
                            else { return }
                            if Int(target.rounded()) != entered { target = Double(entered) }
                        }
                    Spacer()
                }

                Text(footnote)
                    .font(.caption).foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Button("Go to page \(page)") {
                    onJump(page - 1)
                    dismiss()
                }
                .buttonStyle(ActionStyle(primary: true))
                .accessibilityIdentifier("confirm-jump")
            }
            .padding(24)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle("Jump to a page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } }
            }
        }
    }

    /// Says plainly that moving here is browsing, not bookmarking — the same rule the rest of the
    /// reader follows, and the one that surprises most when it is left unsaid.
    private var footnote: String {
        currentPage + 1 == page
            ? "You are on this page. Jumping does not move your bookmark."
            : "Jumping does not move your bookmark — only the bookmark button does."
    }
}
