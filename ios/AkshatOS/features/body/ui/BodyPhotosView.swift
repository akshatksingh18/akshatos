import PhotosUI
import SwiftUI
import UIKit

/// Progress photos, front and side, every two weeks. The first and latest of a pose sit side by
/// side, which is the comparison that matters. Photos stay on the phone.
struct BodyPhotosView: View {
    @ObservedObject var store: BodyLogStore
    @State private var pose: BodyPhotoPose = .front
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var viewing: BodyPhoto?
    @State private var pendingDeletion: BodyPhoto?

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 10)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Surface {
                    Text(store.photosDue ? "Photos are due" : "Next photos due in \(daysUntilDue) days")
                        .font(.headline)
                    Text("Same spot, same light, same pose every two weeks. Photos never leave this phone unless you export a backup.")
                        .font(.caption).foregroundStyle(Palette.muted)
                    Picker("Pose", selection: $pose) {
                        ForEach(BodyPhotoPose.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack(spacing: 12) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Take photo") { showCamera = true }
                                .buttonStyle(ActionStyle(primary: true))
                        }
                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Text("Choose photo")
                        }
                        .buttonStyle(ActionStyle())
                        .accessibilityIdentifier("choose-body-photo")
                    }
                    .disabled(!store.storageAvailable)
                }
                compare
                ForEach(days, id: \.self) { day in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(BodyLogView.dayTitle(day)).font(.subheadline).foregroundStyle(Palette.muted)
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                            ForEach(store.photoRecords.filter { $0.day == day }) { photo in
                                Button { viewing = photo } label: {
                                    BodyPhotoImage(url: store.photoURL(photo)).frame(height: 128)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Delete photo", role: .destructive) { pendingDeletion = photo }
                                }
                                .accessibilityLabel("\(photo.pose.title) photo, \(BodyLogView.dayTitle(day))")
                            }
                        }
                    }
                }
                if store.photoRecords.isEmpty {
                    Text("No photos yet.").font(.subheadline).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("body-photos-empty")
                }
            }
            .padding(20)
        }
        .background(AppBackdrop())
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await store.addPhoto(data, pose: pose)
                } else {
                    store.message = "That photo could not be loaded."
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            BodyCameraPicker { data in
                Task { await store.addPhoto(data, pose: pose) }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $viewing) { photo in
            NavigationStack {
                BodyPhotoImage(url: store.photoURL(photo), fit: true)
                    .padding()
                    .background(Palette.background)
                    .navigationTitle("\(photo.pose.title) · \(BodyLogView.dayTitle(photo.day))")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { Button("Done") { viewing = nil } }
            }
        }
        .confirmationDialog("Delete this photo?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let photo = pendingDeletion { store.deletePhoto(photo) }
                pendingDeletion = nil
            }
        } message: {
            Text("It is removed from this phone. A photo in an exported backup is not affected.")
        }
    }

    /// First and latest photo of the chosen pose, when there are at least two.
    @ViewBuilder private var compare: some View {
        let posed = store.photoRecords.filter { $0.pose == pose }
        if let latest = posed.first, let first = posed.last, first.id != latest.id {
            Surface {
                Text("First and latest").font(.headline)
                HStack(spacing: 10) {
                    ForEach([first, latest]) { photo in
                        VStack(spacing: 6) {
                            BodyPhotoImage(url: store.photoURL(photo)).frame(height: 220)
                            Text(BodyLogView.dayTitle(photo.day)).font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
        }
    }

    private var days: [String] {
        var seen = Set<String>()
        return store.photoRecords.map(\.day).filter { seen.insert($0).inserted }
    }

    private var daysUntilDue: Int {
        guard let latest = store.photoRecords.map(\.day).max(),
              let latestDate = BodyLog.date(fromDay: latest, calendar: .current),
              let todayDate = BodyLog.date(fromDay: store.today, calendar: .current),
              let elapsed = Calendar.current.dateComponents([.day], from: latestDate, to: todayDate).day
        else { return 0 }
        return max(0, BodyLog.photoIntervalDays - elapsed)
    }
}

/// A stored photo, loaded off the main thread.
struct BodyPhotoImage: View {
    let url: URL?
    var fit = false
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Palette.raised
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: fit ? .fit : .fill)
            } else {
                Image(systemName: "photo").foregroundStyle(Palette.muted)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: url?.path) {
            guard let url else { return }
            image = await Task.detached(priority: .utility) { UIImage(contentsOfFile: url.path) }.value
        }
    }
}

/// The system camera. Its delegate is this view's own coordinator, local to the screen.
struct BodyCameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: BodyCameraPicker
        init(_ parent: BodyCameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.95) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
