import SwiftUI

/// One appearance of a video in the feed. A video comes up again in a later round, so the page
/// has its own identity.
struct ReelFeedPage: Identifiable, Equatable {
    let id = UUID()
    let videoID: UUID
}

/// The reel: one video a page, swiped vertically. The video on screen loops until you swipe; tap it
/// to pause or resume. The order is the store's shuffle, extended as you go, so it never runs out.
struct ReelFeedView: View {
    @ObservedObject var store: ReelVaultStore
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var players = ReelPlayerPool()
    @State private var pages: [ReelFeedPage] = []
    @State private var current: UUID?
    @State private var paused = false
    @State private var editing: ReelVideo?
    @State private var draft = ""

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(pages) { page in
                    pageView(page)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(page.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $current)
        .scrollIndicators(.hidden)
        .background(Color.black)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            players.activateAudio()
            extend()
            sync()
        }
        .onDisappear { players.releaseAll() }
        .onChange(of: current) { _, _ in
            paused = false
            extend()
            sync()
        }
        .onChange(of: paused) { _, _ in sync() }
        .onChange(of: scenePhase) { _, _ in sync() }
        .onChange(of: store.videos.map(\.id)) { _, ids in
            // A removed video leaves the feed; a first or newly added one can enter it.
            pages.removeAll { !ids.contains($0.videoID) }
            if let current, !pages.contains(where: { $0.id == current }) { self.current = pages.first?.id }
            extend()
            sync()
        }
        .alert("Headline", isPresented: Binding(get: { editing != nil },
                                                set: { if !$0 { editing = nil; sync() } })) {
            TextField("What is this video?", text: $draft)
                .accessibilityIdentifier("reel-headline-field")
            Button("Save") {
                if let editing { store.setHeadline(draft, for: editing.id) }
                editing = nil
                sync()
            }
            Button("Cancel", role: .cancel) {
                editing = nil
                sync()
            }
        }
    }

    @ViewBuilder private func pageView(_ page: ReelFeedPage) -> some View {
        if let video = store.video(id: page.videoID) {
            ZStack {
                Color.black
                if let player = players.player(for: page.id) {
                    ReelPlayerLayer(player: player)
                } else if store.mediaURL(for: video) == nil {
                    Text("This video's file is missing. Remove it in the library and add it again.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center).padding(32)
                }
                if paused, page.id == current {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 44)).foregroundStyle(.white.opacity(0.85))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { paused.toggle() }
            .overlay(alignment: .topLeading) { headline(video) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reel-page")
        } else {
            Color.black
        }
    }

    /// The headline over the video. Tapping it edits it, with playback held meanwhile.
    private func headline(_ video: ReelVideo) -> some View {
        Button {
            draft = video.headline
            editing = video
            sync()
        } label: {
            Text(video.headline.isEmpty ? "Add a headline" : video.headline)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(video.headline.isEmpty ? 0.7 : 1))
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(16)
        .accessibilityIdentifier("reel-headline")
        .accessibilityLabel(video.headline.isEmpty ? "Add a headline" : "Headline: \(video.headline). Edit")
    }

    /// Keeps a couple of pages queued beyond the one on screen.
    private func extend() {
        let position = pages.firstIndex { $0.id == current } ?? -1
        while pages.count - position - 1 < 2, let next = store.nextInFeed() {
            pages.append(ReelFeedPage(videoID: next.id))
        }
        if current == nil { current = pages.first?.id }
    }

    /// Gives the page on screen and its neighbours a player, and plays only the one on screen:
    /// not while paused, while its headline is being edited, or while the app is not in front.
    private func sync() {
        guard let position = pages.firstIndex(where: { $0.id == current }) else {
            players.prepare([])
            return
        }
        let window = pages[max(0, position - 1)...min(pages.count - 1, position + 1)]
        players.prepare(window.compactMap { page in
            store.video(id: page.videoID).flatMap(store.mediaURL(for:)).map { (page: page.id, url: $0) }
        })
        players.show(current, playing: !paused && editing == nil && scenePhase == .active)
    }
}
