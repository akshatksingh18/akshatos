import SwiftUI
import UniformTypeIdentifiers

struct WatchlistView: View {
    @ObservedObject var store: WatchlistStore
    @State private var search = ""
    @State private var showWatched = false
    @State private var editing: WatchTitle?
    @State private var importing = false
    @State private var exporting = false
    @State private var document: PortableDocument?
    @State private var restore: WatchlistState?
    @State private var importBackup = false
    var body: some View {
        List {
            Toggle("Show watched", isOn: $showWatched)
            if !store.available { Section { Text("Watchlist is unavailable."); Button("Retry") { store.load() } } }
            else {
                let candidates = visible.filter { !store.state.watched($0.id) }
                if let pick = candidates.first(where: \.pick) {
                    Section("Start here") { titleRow(pick) }
                }
                if visible.isEmpty { ContentUnavailableView {
                    Label("Nothing to watch yet", systemImage: "film")
                } actions: {
                    Button("Add title") { editing = WatchTitle(title: "") }
                    Button("Import titles") { importBackup = false; importing = true }
                } }
                ForEach(Array(Set(visible.map(\.mood))).sorted(), id: \.self) { mood in
                    Section(mood) { ForEach(visible.filter { $0.mood == mood }) { titleRow($0) } }
                }
            }
        }.personalList().navigationTitle("Watchlist").searchable(text: $search, prompt: "Titles and notes")
        .task { if !store.available { store.load() } }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Add title", systemImage: "plus") { editing = WatchTitle(title: "") }
                    Button("Import titles") { importBackup = false; importing = true }
                    Button("Export watched events") { prepare(watched: true) }
                    Button("Export full backup") { prepare(watched: false) }
                    Button("Restore full backup") { importBackup = true; importing = true }
                    Button("Undo last metadata import") { store.rollbackImport() }
                } label: { Label("Watchlist actions", systemImage: "ellipsis.circle") }
            }
        }
        .sheet(item: $editing) { title in WatchTitleEditor(store: store, title: title) }
        .personalMessage("Watchlist", message: $store.message)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get(), scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                if importBackup { restore = try LocalDataCoding.decode(WatchlistState.self, data).validated() }
                else { store.preview(data) }
            } catch { store.message = error.localizedDescription }
        }
        .alert("Import Watchlist revision?", isPresented: Binding(get: { store.pendingImport != nil }, set: { if !$0 { store.pendingImport = nil } })) {
            Button("Import") { store.applyImport() }
            Button("Cancel", role: .cancel) { store.pendingImport = nil }
        } message: { Text(store.importDescription) }
        .alert("Replace Watchlist?", isPresented: Binding(get: { restore != nil }, set: { if !$0 { restore = nil } })) {
            Button("Replace", role: .destructive) { if let restore { _ = store.commit(restore, replacingUnavailable: true) }; restore = nil }
            Button("Cancel", role: .cancel) { restore = nil }
        } message: { Text("A full backup replaces titles and watched history. Export the current list first.") }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "akshatos-watchlist") { result in
            if case .failure(let error) = result { store.message = error.localizedDescription }
        }
    }
    private var visible: [WatchTitle] {
        store.state.titles.filter { !$0.deleted && (showWatched || !store.state.watched($0.id))
            && (search.isEmpty || ($0.title + " " + $0.note).localizedCaseInsensitiveContains(search)) }
    }
    private func titleRow(_ title: WatchTitle) -> some View {
        HStack(spacing: 14) {
            Image(systemName: title.kind == "Series" ? "tv" : "film").font(.title2).foregroundStyle(HubInk.sage).frame(width: 40)
            Button { editing = title } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.title).foregroundStyle(.primary)
                    Text(title.kind).font(.caption).foregroundStyle(.secondary)
                    if !title.note.isEmpty { Text(title.note).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }.buttonStyle(.plain)
            Button { store.mark(title.id, watched: !store.state.watched(title.id)) } label: {
                Image(systemName: store.state.watched(title.id) ? "checkmark.circle.fill" : "circle").frame(minWidth: 44, minHeight: 44)
            }.buttonStyle(.plain).accessibilityLabel(store.state.watched(title.id) ? "Mark unwatched" : "Mark watched")
        }
    }
    private func prepare(watched: Bool) {
        do { document = PortableDocument(data: watched ? try store.watchedExport() : try LocalDataCoding.encode(store.state)); exporting = true }
        catch { store.message = error.localizedDescription }
    }
}

private struct WatchTitleEditor: View {
    @ObservedObject var store: WatchlistStore
    @State var title: WatchTitle
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title.title).disabled(title.origin != "phone")
                Picker("Type", selection: $title.kind) { Text("Movie").tag("Movie"); Text("Series").tag("Series") }.disabled(title.origin != "phone")
                TextField("Mood", text: $title.mood).disabled(title.origin != "phone")
                TextField("Note", text: $title.note, axis: .vertical).disabled(title.origin != "phone")
                Toggle("Start here pick", isOn: $title.pick).disabled(title.origin != "phone")
                if title.origin != "phone" { Text("Title details are managed by the laptop file. Watched history is managed on this phone.").font(.footnote).foregroundStyle(.secondary) }
                if store.state.titles.contains(where: { $0.id == title.id && $0.origin == "phone" }) {
                    Button("Remove title", role: .destructive) { var deleted = title; deleted.deleted = true; store.update(deleted); dismiss() }
                }
            }.personalList().navigationTitle("Watch title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") {
                    if store.state.titles.contains(where: { $0.id == title.id }) { store.update(title) }
                    else { store.add(title: title.title, mood: title.mood, kind: title.kind, note: title.note, pick: title.pick) }
                    if store.message == nil { dismiss() }
                }.disabled(title.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.origin != "phone") }
            }.personalMessage("Watchlist", message: $store.message)
        }
    }
}
