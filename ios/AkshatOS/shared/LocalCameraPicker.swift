import SwiftUI
import UIKit

struct LocalCameraPicker: UIViewControllerRepresentable {
    var receive: (Data?) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(receive: receive) }
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let receive: (Data?) -> Void
        init(receive: @escaping (Data?) -> Void) { self.receive = receive }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { receive(nil) }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            receive((info[.originalImage] as? UIImage)?.jpegData(compressionQuality: 0.85))
        }
    }
}
