import SwiftUI

/// A month in a history list that opens and closes, so a long history reads as one row per month
/// and any month is one tap away. Its rows are built only while it is open.
struct MonthGroup<Content: View>: View {
    let title: String
    let summary: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content()
        } label: {
            AdaptiveRow {
                Text(title).font(.headline)
            } trailing: {
                Text(summary).font(.subheadline).monospacedDigit().foregroundStyle(Palette.muted)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

enum MonthKey {
    /// `yyyy-MM` as a readable month, such as "September 2026".
    static func title(_ key: String) -> String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM"
        guard let date = parser.date(from: key) else { return key }
        return date.formatted(.dateTime.month(.wide).year())
    }
}

/// Which months are open. The newest starts open; the rest stay closed until tapped.
struct OpenMonths {
    private var open: Set<String> = []
    private var seeded = false

    /// Opens the newest month the first time there is one.
    mutating func seed(newest: String?) {
        guard !seeded, let newest else { return }
        open.insert(newest)
        seeded = true
    }

    func isOpen(_ id: String) -> Bool { open.contains(id) }

    mutating func set(_ id: String, open isOpen: Bool) {
        if isOpen { open.insert(id) } else { open.remove(id) }
    }
}

extension Binding where Value == OpenMonths {
    func month(_ id: String) -> Binding<Bool> {
        Binding<Bool>(get: { wrappedValue.isOpen(id) }, set: { wrappedValue.set(id, open: $0) })
    }
}
