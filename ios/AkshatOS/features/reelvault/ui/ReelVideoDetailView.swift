import SwiftUI

/// A still of the video, or a placeholder until it is ready or when the file cannot be read.
struct ReelThumbnail: View {
    let url: URL?
    @State private var image: CGImage?

    var body: some View {
        ZStack {
            Color.black
            if let image {
                Image(decorative: image, scale: 1).resizable().scaledToFill()
            } else {
                Image(systemName: "film").foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: 54, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: url) {
            guard let url else { image = nil; return }
            image = await ReelThumbnailer.shared.thumbnail(for: url)
        }
        .accessibilityHidden(true)
    }
}

/// One video from the library: it plays here, looping, so you can see what it is while giving it a
/// headline, and it can be deleted.
struct ReelVideoDetailView: View {
    @ObservedObject var store: ReelVaultStore
    let videoID: UUID
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var players = ReelPlayerPool()
    @State private var draft = ""
    @State private var paused = false
    @State private var confirmingDelete = false
    @FocusState private var editingHeadline: Bool

    var body: some View {
        Group {
            if let video = store.video(id: videoID) {
                content(video)
            } else {
                Color.black
            }
        }
        .background(Color.black)
        .navigationTitle("Video")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            draft = store.video(id: videoID)?.headline ?? ""
            players.activateAudio()
            sync()
        }
        .onDisappear {
            saveHeadline()
            players.releaseAll()
        }
        .onChange(of: paused) { _, _ in sync() }
        .onChange(of: scenePhase) { _, _ in sync() }
        .onChange(of: confirmingDelete) { _, _ in sync() }
        .confirmationDialog("Delete this video?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete video", role: .destructive) {
                players.releaseAll()
                store.remove(videoID)
                dismiss()
            }
            .accessibilityIdentifier("confirm-delete-reel")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The copy in AkshatOS is deleted. The original in Photos or Files is not touched.")
        }
    }

    private func content(_ video: ReelVideo) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Color.black
                if let player = players.player(for: videoID) {
                    ReelPlayerLayer(player: player)
                } else {
                    Text("This video's file is missing. Delete it and add it again.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center).padding(32)
                }
                if paused {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 44)).foregroundStyle(.white.opacity(0.85))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { paused.toggle() }
            .accessibilityIdentifier("reel-detail-player")

            VStack(alignment: .leading, spacing: 10) {
                Text("Headline").font(.caption).foregroundStyle(.white.opacity(0.7))
                TextField("What is this video?", text: $draft)
                    .focused($editingHeadline)
                    .submitLabel(.done)
                    .onSubmit(saveHeadline)
                    .padding(12)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("reel-detail-headline")
                Text(ReelLibraryView.detail(video)).font(.caption).foregroundStyle(.white.opacity(0.6))
                Button(role: .destructive) {
                    editingHeadline = false
                    confirmingDelete = true
                } label: {
                    Label("Delete video", systemImage: "trash").frame(maxWidth: .infinity)
                }
                .buttonStyle(ActionStyle())
                .accessibilityIdentifier("delete-reel")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    /// Saved when you press Done or leave the screen, so a typed headline is never lost.
    private func saveHeadline() {
        guard let video = store.video(id: videoID), ReelVault.headline(draft) != video.headline else { return }
        store.setHeadline(draft, for: videoID)
    }

    private func sync() {
        guard let video = store.video(id: videoID), let url = store.mediaURL(for: video) else {
            players.prepare([])
            return
        }
        players.prepare([(page: videoID, url: url)])
        players.show(videoID, playing: !paused && !confirmingDelete && scenePhase == .active)
    }
}
