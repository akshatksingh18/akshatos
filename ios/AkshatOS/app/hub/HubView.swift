import SwiftUI

struct HubView<Destination: View>: View {
    let entries: [HubEntry]
    @ViewBuilder var destination: (HubRoute) -> Destination

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(Palette.lime).font(.title2)
                        Spacer()
                        Text("YOUR PERSONAL SPACE")
                            .font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Palette.muted)
                    }.padding(.top, 18)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("AkshatOS").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Small rituals. Your own rhythm.")
                            .font(.body).foregroundStyle(Palette.muted)
                    }

                    ForEach(entries.filter(\.isAvailable)) { entry in
                        NavigationLink {
                            destination(entry.id)
                        } label: {
                            Surface {
                                HStack(alignment: .top) {
                                    Image(systemName: entry.icon)
                                        .font(.system(size: 34)).foregroundStyle(Palette.lime)
                                        .frame(width: 68, height: 68)
                                        .background(Palette.lime.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                                    Spacer()
                                    Image(systemName: "arrow.up.right").font(.title3).foregroundStyle(Palette.muted)
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(entry.title).font(.system(.title2, design: .rounded, weight: .bold))
                                    Text(entry.subtitle).font(.subheadline).foregroundStyle(Palette.muted)
                                }
                                HStack {
                                    Label(entry.status, systemImage: entry.statusIcon)
                                        .font(.caption.weight(.semibold)).foregroundStyle(Palette.lime)
                                    Spacer()
                                    Text(entry.detail).font(.caption).foregroundStyle(Palette.muted)
                                }
                            }
                        }.buttonStyle(.plain).accessibilityIdentifier("open-\(entry.id.rawValue)")
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("ROOM TO GROW").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Palette.muted)
                        ForEach(entries.filter { !$0.isAvailable }) { entry in
                            HStack(spacing: 16) {
                                Image(systemName: entry.icon).font(.title3).frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.title).font(.headline)
                                    Text(entry.subtitle).font(.caption)
                                }
                                Spacer()
                                Text("LATER").font(.caption2.weight(.bold)).tracking(1)
                            }.foregroundStyle(Palette.muted).padding(18)
                                .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 20))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(entry.title), planned for later, not available yet")
                        }
                    }
                    Text("Built for one. Built for you.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                }.padding(24)
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }.tint(Palette.lime)
    }
}
