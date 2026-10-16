import SwiftUI

/// Shared with the WidgetKit target so the real lock-screen content can be rendered in XCTest.
struct StudyActivityCard: View {
    let state: StudyActivityAttributes.ContentState
    let stale: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(stale ? "Study · open app to refresh" : "Studying", systemImage: "book")
                .font(.headline)
            if stale {
                Text("Study recording continues. Open AkshatOS for today’s total.").font(.subheadline)
            } else if typeSize.isAccessibilitySize {
                elapsed
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    elapsed
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(timerInterval: state.remainingRange, countsDown: true, showsHours: true)
                            .font(.title3).monospacedDigit().multilineTextAlignment(.trailing)
                        Text("Remaining").font(.caption)
                    }
                }
            }
        }.foregroundStyle(.white).padding(16)
            .accessibilityElement(children: .combine)
    }
    private var elapsed: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timerInterval: state.elapsedRange, countsDown: false, showsHours: true)
                .font(.largeTitle.weight(.medium)).monospacedDigit().multilineTextAlignment(.leading)
            Text("Studied today").font(.caption)
        }
    }
}
