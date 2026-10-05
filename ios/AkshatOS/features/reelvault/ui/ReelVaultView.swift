import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// ReelVault's home: the feed once there is a video, otherwise how to add the first one.
struct ReelVaultView: View {
    @ObservedObject var store: ReelVaultStore
    @State private var reshuffles = 0

    var body: some View {
        Group {
            if store.videos.isEmpty {
                empty
            } else {
                ReelFeedView(store: store, reshuffles: reshuffles)
            }
        }
        .navigationTitle("ReelVault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.videos.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        reshuffles += 1
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .accessibilityIdentifier("reshuffle-reels")
                    .accessibilityLabel("Reshuffle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ReelLibraryView(store: store)
                } label: {
                    Image(systemName: "rectangle.stack")
                }
                .accessibilityIdentifier("open-reel-library")
                .accessibilityLabel("Library")
            }
        }
        .alert("ReelVault", isPresented: Binding(get: { store.message != nil },
                                                 set: { if !$0 { store.message = nil } })) {
            Button("OK") { store.message = nil }
        } message: { Text(store.message ?? "") }
    }

    private var empty: some View {
        ZStack {
            AppBackdrop()
            VStack(alignment: .leading, spacing: 16) {
                Surface {
                    Text("No videos yet").font(.headline)
                    Text("Add videos you own from Photos or Files. They are copied into AkshatOS, so the originals can be moved or deleted afterwards. Give each a headline and swipe through them here.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    ReelAddButtons(store: store)
                }
                Spacer()
            }
            .padding(20)
        }
    }
}

/// The two ways in: the system photo picker, which needs no photo permission, and Files.
struct ReelAddButtons: View {
    @ObservedObject var store: ReelVaultStore
    @State private var picked: [PhotosPickerItem] = []
    @State private var showFiles = false

    var body: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $picked, maxSelectionCount: 10, matching: .videos) {
                Label("Add from Photos", systemImage: "photo.on.rectangle")
            }
            .buttonStyle(ActionStyle(primary: true))
            .accessibilityIdentifier("add-reels-photos")
            Button {
                showFiles = true
            } label: {
                Label("Add from Files", systemImage: "folder")
            }
            .buttonStyle(ActionStyle())
            .accessibilityIdentifier("add-reels-files")
            if store.importing > 0 {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Copying…").font(.subheadline).foregroundStyle(Palette.muted)
                }
            }
        }
        .disabled(!store.storageAvailable)
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            picked = []
            Task { await addPicked(items) }
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie, .video],
                      allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result, !urls.isEmpty else { return }
            Task { await store.importVideos(from: urls) }
        }
    }

    /// Photos hands each video over as a temporary file; it is copied in and the temporary removed.
    private func addPicked(_ items: [PhotosPickerItem]) async {
        var urls: [URL] = []
        var unreadable = 0
        for item in items {
            if let movie = try? await item.loadTransferable(type: ReelPickedMovie.self) {
                urls.append(movie.url)
            } else {
                unreadable += 1
            }
        }
        await store.importVideos(from: urls, deleteSources: true)
        if unreadable > 0, store.message == nil {
            store.message = unreadable == 1 ? "1 video could not be read from Photos."
                                            : "\(unreadable) videos could not be read from Photos."
        }
    }
}

/// A video picked in Photos, received as a file rather than loaded into memory.
struct ReelPickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("ReelVaultPicked", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let kind = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(kind)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return ReelPickedMovie(url: copy)
        }
    }
}
