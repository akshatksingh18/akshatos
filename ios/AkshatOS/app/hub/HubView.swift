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
                    VStack(alignment: .leading, spacing: 28) {
                        HStack {
                            QuestBadge(text: "Homebase", icon: "sparkles", accent: Palette.lime)
                            Spacer()
                            Image(systemName: "circle.hexagongrid.fill")
                                .font(.title2).foregroundStyle(Palette.violet)
                                .accessibilityHidden(true)
                        }.padding(.top, 18)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("AkshatOS")
                                .font(.system(.largeTitle, design: .rounded, weight: .black))
                            Text("Your tiny universe,\nready to play.")
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text("Pick a quest. Make a little progress. Come back tomorrow.")
                                .font(.body).foregroundStyle(Palette.muted)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("akshatos-homebase")

                        ForEach(entries.filter(\.isAvailable)) { entry in
                            NavigationLink(value: entry.id) { moduleCard(entry) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("open-\(entry.id.rawValue)")
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            QuestBadge(text: "Next portal", icon: "lock.fill", accent: Palette.violet)
                            ForEach(entries.filter { !$0.isAvailable }) { entry in
                                HStack(spacing: 16) {
                                    Image(systemName: entry.icon)
                                        .font(.title2).foregroundStyle(Palette.violet)
                                        .frame(width: 52, height: 52)
                                        .background(Palette.violet.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.title).font(.headline)
                                        Text(entry.subtitle).font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    Spacer()
                                    Text("LOCKED")
                                        .font(.caption2.weight(.black)).tracking(1)
                                        .foregroundStyle(Palette.violet)
                                }
                                .padding(18)
                                .background(Palette.cardGradient, in: RoundedRectangle(cornerRadius: 22))
                                .overlay(RoundedRectangle(cornerRadius: 22)
                                    .stroke(Palette.violet.opacity(0.18)))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(entry.title), planned for later, not available yet")
                            }
                        }
                        Text("PRIVATE BY DEFAULT  •  BUILT FOR ONE")
                            .font(.caption2.weight(.bold)).tracking(1.3).foregroundStyle(Palette.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                    }.padding(24)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HubRoute.self) { destination($0) }
        }.tint(Palette.lime)
    }

    private func moduleCard(_ entry: HubEntry) -> some View {
        let accent = accent(for: entry.id)
        return AccentSurface(accent: accent) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 12) {
                    QuestBadge(text: kicker(for: entry.id), icon: badgeIcon(for: entry.id), accent: accent)
                    Image(systemName: entry.icon)
                        .font(.system(size: 34, weight: .semibold)).foregroundStyle(accent)
                        .frame(width: 68, height: 68)
                        .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.title3.weight(.bold)).foregroundStyle(accent)
                    .padding(12).background(accent.opacity(0.11), in: Circle())
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.title).font(.system(.title2, design: .rounded, weight: .black))
                Text(entry.subtitle).font(.subheadline).foregroundStyle(Palette.muted)
            }
            HStack {
                Label(entry.status, systemImage: entry.statusIcon)
                    .font(.caption.weight(.bold)).foregroundStyle(accent)
                Spacer()
                Text(entry.detail).font(.caption.monospacedDigit()).foregroundStyle(Palette.muted)
            }
        }
    }

    private func accent(for route: HubRoute) -> Color {
        switch route {
        case .squats: return Palette.coral
        case .pageVault: return Palette.aqua
        case .liftLog: return Palette.gold
        case .reelVault: return Palette.violet
        }
    }

    private func kicker(for route: HubRoute) -> String {
        switch route {
        case .squats: return "Power-up"
        case .pageVault: return "Story quest"
        case .liftLog: return "Strength log"
        case .reelVault: return "Watchlist warp"
        }
    }

    private func badgeIcon(for route: HubRoute) -> String {
        switch route {
        case .squats: return "bolt.fill"
        case .pageVault: return "bookmark.fill"
        case .liftLog: return "dumbbell.fill"
        case .reelVault: return "play.fill"
        }
    }
}
