import SwiftUI

struct HubView<Destination: View>: View {
    let entries: [HubEntry]
    /// Held outside the stack so a feature can be opened without the user tapping its card — which
    /// is what a tapped alert needs.
    @Binding var path: [HubRoute]
    @ViewBuilder var destination: (HubRoute) -> Destination

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("AkshatOS").font(.largeTitle.bold())
                            Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                                .font(.subheadline).foregroundStyle(Palette.muted)
                        }
                        .padding(.top, 24).padding(.bottom, 12)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("akshatos-homebase")

                        ForEach(entries.filter(\.isAvailable)) { entry in
                            NavigationLink(value: entry.id) { moduleRow(entry) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("open-\(entry.id.rawValue)")
                        }

                        ForEach(entries.filter { !$0.isAvailable }) { entry in
                            HStack(spacing: 14) {
                                icon(entry.icon).opacity(0.5)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).font(.body.weight(.semibold))
                                    Text(entry.subtitle).font(.subheadline)
                                }
                                Spacer()
                            }
                            .padding(16)
                            .foregroundStyle(Palette.muted)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(entry.title), not available yet")
                        }
                    }.padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HubRoute.self) { destination($0) }
        }.tint(Palette.accent)
    }

    private func moduleRow(_ entry: HubEntry) -> some View {
        Surface {
            HStack(spacing: 14) {
                icon(entry.icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title).font(.body.weight(.semibold))
                    Text(entry.detail.isEmpty ? entry.status : "\(entry.status) · \(entry.detail)")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Palette.muted)
                    .accessibilityHidden(true)
            }
        }
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.title3).foregroundStyle(Palette.accent)
            .frame(width: 40, height: 40)
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}
