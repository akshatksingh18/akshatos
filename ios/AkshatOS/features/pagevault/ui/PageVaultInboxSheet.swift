import SwiftUI
import UniformTypeIdentifiers

/// Links the inbox folder: a folder, normally in OneDrive, that the laptop saves PDFs into.
/// PageVault copies in whatever is new there each time it opens.
struct PageVaultInboxSheet: View {
    @ObservedObject var store: PageVaultStore

    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var confirmUnlink = false
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let name = store.inboxFolderName {
                        LabeledContent("Folder", value: name)
                            .accessibilityIdentifier("pagevault-inbox-folder")
                        if store.inboxNeedsRelink {
                            Label("PageVault can no longer reach this folder. Link it again.",
                                  systemImage: "exclamationmark.triangle")
                                .foregroundStyle(Palette.coral)
                        }
                        Button {
                            Task { await store.syncInbox() }
                        } label: {
                            Label("Check for new PDFs", systemImage: "arrow.clockwise")
                        }
                        .accessibilityIdentifier("pagevault-inbox-check")
                        Button { showPicker = true } label: {
                            Label(store.inboxNeedsRelink ? "Link the folder again" : "Link a different folder",
                                  systemImage: "folder.badge.gearshape")
                        }
                        Button("Unlink folder", role: .destructive) { confirmUnlink = true }
                            .accessibilityIdentifier("pagevault-inbox-unlink")
                    } else {
                        Button { showPicker = true } label: {
                            Label("Link a folder", systemImage: "folder.badge.plus")
                        }
                        .accessibilityIdentifier("pagevault-inbox-link")
                    }
                } header: {
                    Text("Inbox folder")
                } footer: {
                    Text("Save PDFs on your laptop into a OneDrive folder, then link that folder here. Each time you open PageVault, every new PDF in it is copied into your library. PageVault only reads the folder: nothing there is moved or deleted, and a book you remove is not added again. OneDrive appears in the picker once its app is installed on this iPhone.")
                }
                if store.inboxChecking {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Checking the folder…").foregroundStyle(Palette.muted)
                        }
                    }
                } else if let report = store.inboxReport {
                    Section {
                        Text(report.summary).accessibilityIdentifier("pagevault-inbox-report")
                        ForEach(report.rejected + report.deferred, id: \.self) { line in
                            Text(line).font(.footnote).foregroundStyle(Palette.muted)
                        }
                    } header: {
                        Text("Last check")
                    }
                }
            }
            .fileImporter(isPresented: $showPicker, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let folder):
                    Task { notice = await store.linkInbox(folder) }
                case .failure(let error):
                    notice = "That folder could not be opened: \(error.localizedDescription)"
                }
            }
            .alert("PageVault", isPresented: Binding(
                get: { notice != nil },
                set: { if !$0 { notice = nil } }
            )) {
                Button("OK") { notice = nil }
            } message: {
                Text(notice ?? "")
            }
            .confirmationDialog("Unlink this folder?", isPresented: $confirmUnlink,
                                titleVisibility: .visible) {
                Button("Unlink", role: .destructive) { store.unlinkInbox() }
                Button("Keep", role: .cancel) {}
            } message: {
                Text("Books already added stay in your library, and the folder is not changed. Linking it again later adds its PDFs again, except any already in your library.")
            }
            .navigationTitle("Laptop inbox")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
