import SwiftUI

struct StudyDial: View {
    var studied: Double
    var target: Int
    var compact = false
    @State private var showingStudied = false
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 48
    @Environment(\.dynamicTypeSize) private var typeSize
    private var fraction: Double { min(1, max(0, studied / Double(max(1, target)))) }
    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: 0.75).stroke(.white.opacity(0.14), style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: 0.75 * fraction)
                .stroke(LinearGradient(colors: [HubInk.copper.opacity(0.65), HubInk.copper, Color(red: 0.94, green: 0.77, blue: 0.63)], startPoint: .bottomLeading, endPoint: .topTrailing), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(135))
                .opacity(fraction > 0 ? 1 : 0)
            DialTickShape().stroke(HubInk.sage.opacity(0.8), lineWidth: 1).padding(-13)
            Button { showingStudied.toggle() } label: {
                VStack(spacing: 8) {
                    Text(StudyTimeDisplay.short(showingStudied ? studied : max(0, Double(target) - studied)))
                        .font(.system(size: numberSize, weight: .medium, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.6).lineLimit(1).foregroundStyle(.primary)
                        .accessibilityIdentifier(showingStudied ? "study-studied-dial" : "study-remaining")
                    HStack(spacing: 6) {
                        Text(showingStudied ? "Studied" : "Remaining")
                        Image(systemName: "arrow.left.arrow.right").font(.caption2)
                    }.font(.subheadline).lineLimit(1).minimumScaleFactor(0.7).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, minHeight: 100).contentShape(Circle())
            }.buttonStyle(.plain).padding(compact ? 8 : 24).accessibilityLabel(showingStudied ? "Show remaining time" : "Show studied time")
            VStack {
                Spacer()
                HStack {
                    Text("0h"); Spacer(); Text("\(Double(target) / 3600, specifier: "%g")h aim"); Spacer(); Text("\(Double(target) / 3600, specifier: "%g")h")
                }.font(.caption).foregroundStyle(.secondary).offset(y: 18)
            }
        }
        .padding(16).frame(maxWidth: typeSize.isAccessibilitySize ? 380 : 280)
        .aspectRatio(1.12, contentMode: .fit)
        .accessibilityValue("\(StudyTimeDisplay.short(studied)) studied of \(StudyTimeDisplay.short(Double(target)))")
    }
}

private struct DialTickShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2, center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for index in 0...36 {
            let angle = (135 + Double(index) * 7.5) * .pi / 180
            let inner = radius - (index % 6 == 0 ? 10 : 4)
            path.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner))
            path.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius))
        }
        return path
    }
}
