import SwiftUI
import UniformTypeIdentifiers

/// Every video in ReelVault, each with a still so you can tell them apart: add more, open one to
/// watch it, give it a headline or delete it, and back the library up.
struct ReelLibraryView: View {
    @ObservedObject var store: ReelVaultStore
    @State private var pendingRemoval: ReelVideo?
    @State private var staged: URL?
    @State private var showMover = false
    @State private var showRestore = false
    @State private var pendingRestore: ReelVaultStore.PreparedRestore?

    var body: some View {
        List {
            Section {
                ReelAddButtons(store: store)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                if store.videos.isEmpty {
                    Text("No videos yet.").foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("reel-library-empty")
                }
                ForEach(store.videos) { video in
                    NavigationLink {
                        ReelVideoDetailView(store: store, videoID: video.id)
                    } label: {
                        HStack(spacing: 12) {
                            ReelThumbnail(url: store.mediaURL(for: video))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.headline.isEmpty ? "No headline" : video.headline)
                                    .foregroundStyle(video.headline.isEmpty ? Palette.muted : Color.primary)
                                Text(Self.detail(video)).font(.caption).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                    .accessibilityIdentifier("reel-library-row")
                    .swipeActions {
                        Button("Delete", role: .destructive) { pendingRemoval = video }
                    }
                }
            } header: {
                Text(store.videos.count == 1 ? "1 video" : "\(store.videos.count) videos")
            } footer: {
                if !store.videos.isEmpty {
                    Text("Tap a video to watch it, give it a headline or delete it. You can also swipe left to delete. \(Self.size(store.totalBytes)) on this iPhone.")
                }
            }
            Section {
                Button("Export backup") {
                    Task {
                        do {
                            staged = try await store.stageBackup()
                            showMover = true
                        } catch {
                            store.message = error.localizedDescription
                        }
                    }
                }
                .disabled(store.videos.isEmpty)
                .accessibilityIdentifier("export-reels")
                Button("Restore backup") { showRestore = true }
                    .accessibilityIdentifier("restore-reels")
            } header: {
                Text("Your data")
            } footer: {
                Text("The backup is a folder with every video and its headline. Uninstalling AkshatOS deletes them from the phone, so keep a backup somewhere else. The hub's Backup screen includes it too.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .alert(Self.deleteTitle(pendingRemoval), isPresented: Binding(get: { pendingRemoval != nil },
                                                          set: { if !$0 { pendingRemoval = nil } })) {
            Button("Delete", role: .destructive) {
                if let pendingRemoval { store.remove(pendingRemoval.id) }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("The copy in AkshatOS is deleted. The original in Photos or Files is not touched.")
        }
        .alert("Restore this backup?", isPresented: Binding(get: { pendingRestore != nil },
                                                            set: { if !$0 { pendingRestore = nil } })) {
            Button("Restore") {
                guard let prepared = pendingRestore else { return }
                pendingRestore = nil
                Task {
                    do { store.message = "Restored: " + (try await store.restore(prepared)) }
                    catch { store.message = error.localizedDescription }
                }
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            Text(Self.restoreSummary(pendingRestore?.plan))
        }
        // Messages are shown by the ReelVault screen underneath, which owns the one alert for them.
        .fileMover(isPresented: $showMover, file: staged) { _ in
            staged = nil
            store.finishExport()
        }
        .fileImporter(isPresented: $showRestore, allowedContentTypes: [.folder]) { result in
            guard case .success(let url) = result else { return }
            do { pendingRestore = try store.prepareRestore(from: url) }
            catch { store.message = error.localizedDescription }
        }
    }

    static func detail(_ video: ReelVideo) -> String {
        "\(ReelVault.durationText(video.duration)) · \(size(video.byteCount)) · \(video.importedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    /// Names the video by its headline when it has one, so the right one is deleted.
    static func deleteTitle(_ video: ReelVideo?) -> String {
        guard let video, !video.headline.isEmpty else { return "Delete this video?" }
        return "Delete \u{201C}\(video.headline)\u{201D}?"
    }

    static func size(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func restoreSummary(_ plan: ReelRestorePlan?) -> String {
        guard let plan else { return "" }
        var parts: [String] = []
        if !plan.additions.isEmpty {
            parts.append(plan.additions.count == 1 ? "1 video will be added" : "\(plan.additions.count) videos will be added")
        }
        if !plan.headlineChanges.isEmpty {
            parts.append(plan.headlineChanges.count == 1 ? "1 headline will be updated" : "\(plan.headlineChanges.count) headlines will be updated")
        }
        return parts.joined(separator: " and ") + ". Nothing already here is removed."
    }
}
