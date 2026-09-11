import SwiftUI
import UniformTypeIdentifiers

/// Export and restore. Exports are staged inside the app and handed to the system file mover;
/// restores are validated in full and confirmed before anything in the library changes.
struct PageVaultBackupSheet: View {
    @ObservedObject var store: PageVaultStore

    @Environment(\.dismiss) private var dismiss
    @State private var staged: URL?
    @State private var showMover = false
    @State private var showImporter = false
    @State private var pending: PageVaultStore.PageVaultPreparedRestore?
    @State private var notice: String?
    @State private var working = false

    private var librarySize: String {
        ByteCountFormatter.string(fromByteCount: store.books.reduce(Int64(0)) { $0 + $1.byteCount },
                                  countStyle: .file)
    }

    var body: some View {
        // The mover and the importer sit on different views: stacking file dialogs on one view is
        // a known way for one of them to stop presenting.
        NavigationStack {
            List {
                Section {
                    Button { export(includeDocuments: true) } label: {
                        Label("Export library with PDFs", systemImage: "folder")
                    }
                    .accessibilityIdentifier("pagevault-export-full")
                    Button { export(includeDocuments: false) } label: {
                        Label("Export reading data only", systemImage: "doc.text")
                    }
                    .accessibilityIdentifier("pagevault-export-data")
                } header: {
                    Text("Export")
                } footer: {
                    Text("The full export is a folder with every PDF (\(librarySize)) and a manifest. Reading data is one small file of places, statuses, goals and streak history that restores onto PDFs you add again. Uninstalling AkshatOS deletes PageVault's copies, so keep a full export somewhere else first.")
                }
                Section {
                    Button { showImporter = true } label: {
                        Label("Restore from an export", systemImage: "arrow.counterclockwise")
                    }
                    .accessibilityIdentifier("pagevault-restore")
                } header: {
                    Text("Restore")
                } footer: {
                    Text("Choose an export folder or a reading-data file. Every PDF is checked against its checksum, and nothing changes until you confirm.")
                }
                if working {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Working…").foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
            .disabled(working)
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder, .json]) { result in
                switch result {
                case .success(let url):
                    prepareRestore(from: url)
                case .failure(let error):
                    notice = "That could not be opened: \(error.localizedDescription)"
                }
            }
            .navigationTitle("Back up PageVault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .interactiveDismissDisabled(working)
        .fileMover(isPresented: $showMover, file: staged) { result in
            switch result {
            case .success:
                notice = "Export saved."
            case .failure(let error):
                if (error as? CocoaError)?.code != .userCancelled {
                    notice = "The export was not saved: \(error.localizedDescription)"
                }
            }
            store.finishExport()
            staged = nil
        }
        .confirmationDialog("Restore from this export?", isPresented: Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } }
        ), titleVisibility: .visible, presenting: pending) { prepared in
            if prepared.plan.matches.isEmpty {
                Button("Restore") { restore(prepared, mode: .addMissing) }
            } else {
                Button("Replace their place and history", role: .destructive) {
                    restore(prepared, mode: .replaceMatching)
                }
                if !prepared.plan.additions.isEmpty {
                    Button("Only add missing books") { restore(prepared, mode: .addMissing) }
                }
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { prepared in
            Text(Self.describe(prepared.plan))
        }
        .alert("PageVault", isPresented: Binding(
            get: { notice != nil },
            set: { if !$0 { notice = nil } }
        )) {
            Button("OK") { notice = nil }
        } message: {
            Text(notice ?? "")
        }
    }

    private func export(includeDocuments: Bool) {
        working = true
        Task {
            defer { working = false }
            do {
                staged = try await store.prepareExport(includeDocuments: includeDocuments)
                showMover = true
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func prepareRestore(from url: URL) {
        working = true
        Task {
            defer { working = false }
            do {
                pending = try await store.prepareRestore(from: url)
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private func restore(_ prepared: PageVaultStore.PageVaultPreparedRestore, mode: PageVaultRestoreMode) {
        pending = nil
        working = true
        Task {
            defer { working = false }
            do {
                notice = try await store.restore(prepared, mode: mode)
            } catch {
                notice = error.localizedDescription
            }
        }
    }

    private static func describe(_ plan: PageVaultRestorePlan) -> String {
        func books(_ count: Int) -> String { count == 1 ? "1 book" : "\(count) books" }
        var lines: [String] = []
        if !plan.additions.isEmpty {
            lines.append("Adds \(books(plan.additions.count)) with their PDFs.")
        }
        if !plan.matches.isEmpty {
            lines.append("Already in your library: \(books(plan.matches.count)). Replacing gives them this export's place, status, goal and reading history, and their current ones are lost.")
        }
        if !plan.missingDocuments.isEmpty {
            lines.append("\(books(plan.missingDocuments.count)) not in your library cannot come back without their PDFs.")
        }
        return lines.joined(separator: " ")
    }
}
