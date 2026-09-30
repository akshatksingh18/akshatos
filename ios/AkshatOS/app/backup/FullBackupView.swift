import SwiftUI
import UniformTypeIdentifiers

/// Back up or restore every module at once. Each module's own backup still works on its own.
struct FullBackupView: View {
    @ObservedObject var service: FullBackupService
    @State private var staged: URL?
    @State private var showMover = false
    @State private var showImporter = false
    @State private var pending: FullBackupService.PreparedRestore?
    @State private var result: String?

    var body: some View {
        Form {
            Section {
                Button {
                    Task { await backUp() }
                } label: {
                    Label("Back up everything", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("backup-everything")
            } footer: {
                Text("One folder with Pushups, PageVault with your PDFs, Lift Log, and Body with your photos. Save it somewhere off the phone, such as OneDrive in Files.")
            }
            Section {
                Button {
                    showImporter = true
                } label: {
                    Label("Restore everything", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("restore-everything")
            } footer: {
                Text("Pick the \"AkshatOS Backup\" folder. Pushups, Lift Log and Body are replaced by the backup. PageVault adds missing books and updates the ones already here. Not in the backup: notification and location permissions and the Pushups Home area.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Backup")
        .disabled(service.working)
        .overlay { if service.working { ProgressView().controlSize(.large) } }
        .fileMover(isPresented: $showMover, file: staged) { outcome in
            if case .success = outcome { result = "Backup saved." }
            staged = nil
            service.finishExport()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.folder]) { picked in
            guard case .success(let url) = picked else { return }
            Task {
                do { pending = try await service.prepareRestore(from: url) }
                catch { result = error.localizedDescription }
            }
        }
        .alert("Restore everything?", isPresented: Binding(
            get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Restore", role: .destructive) {
                guard let prepared = pending else { return }
                pending = nil
                Task { result = await service.restore(prepared) }
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("This backup has \(pending?.titles.joined(separator: ", ") ?? ""). What is on the phone now for those is replaced. Back up first if you need it.")
        }
        .alert("Backup", isPresented: Binding(
            get: { result != nil }, set: { if !$0 { result = nil } })) {
            Button("OK") { result = nil }
        } message: {
            Text(result ?? "")
        }
    }

    private func backUp() async {
        do {
            staged = try await service.prepareExport()
            showMover = true
        } catch {
            result = error.localizedDescription
        }
    }
}
