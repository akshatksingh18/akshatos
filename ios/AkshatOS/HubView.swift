import SwiftUI

enum Palette {
    static let background = Color(red: 0.035, green: 0.055, blue: 0.085)
    static let card = Color(red: 0.085, green: 0.11, blue: 0.15)
    static let lime = Color(red: 0.76, green: 0.97, blue: 0.43)
    static let muted = Color(red: 0.65, green: 0.70, blue: 0.77)
}

struct Surface<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 18) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(.white.opacity(0.06)))
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

struct HubView: View {
    @EnvironmentObject private var store: SquatStore
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

                    NavigationLink {
                        SquatDashboard()
                    } label: {
                        Surface {
                            HStack(alignment: .top) {
                                Image(systemName: "figure.strengthtraining.traditional")
                                    .font(.system(size: 34)).foregroundStyle(Palette.lime)
                                    .frame(width: 68, height: 68)
                                    .background(Palette.lime.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.title3).foregroundStyle(Palette.muted)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Squat Reminder").font(.system(.title2, design: .rounded, weight: .bold))
                                Text("Make room for a little movement.")
                                    .font(.subheadline).foregroundStyle(Palette.muted)
                            }
                            HStack {
                                Label(store.operational, systemImage: store.active == nil ? "sun.max" : "circle.fill")
                                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.lime)
                                Spacer()
                                Text("\(store.todayCount) sets today").font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }.buttonStyle(.plain).accessibilityIdentifier("open-squats")

                    VStack(alignment: .leading, spacing: 14) {
                        Text("ROOM TO GROW").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(Palette.muted)
                        futureModule("PageVault", subtitle: "Your reading corner", icon: "book.closed")
                        futureModule("ReelVault", subtitle: "Your personal reel collection", icon: "play.rectangle")
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

    private func futureModule(_ title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon).font(.title3).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption)
            }
            Spacer()
            Text("LATER").font(.caption2.weight(.bold)).tracking(1)
        }.foregroundStyle(Palette.muted).padding(18)
            .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), planned for later, not available yet")
    }
}
