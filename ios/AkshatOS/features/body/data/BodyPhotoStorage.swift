import Foundation
import UIKit

/// Progress photos as JPEG files in the app's own storage. They never leave the phone unless you
/// export a backup. Like PageVault's PDFs they are included in the phone's own device backup.
struct BodyPhotoStorage: Sendable {
    static let maxPixel: CGFloat = 2048

    let root: URL

    init(root: URL? = nil) throws {
        if let root {
            self.root = root
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: true)
            self.root = support.appendingPathComponent("BodyLog/Photos", isDirectory: true)
        }
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func url(for photo: BodyPhoto) -> URL { root.appendingPathComponent(photo.fileName) }

    /// Re-encodes the picked image as a JPEG no larger than `maxPixel` on its long side, which also
    /// bakes in its orientation and drops the original's location metadata.
    static func jpeg(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        let longest = max(pixels.width, pixels.height)
        guard longest > 0 else { return nil }
        let factor = min(1, maxPixel / longest)
        let size = CGSize(width: (pixels.width * factor).rounded(), height: (pixels.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.8)
    }

    func write(_ jpeg: Data, for photo: BodyPhoto) throws {
        try jpeg.write(to: url(for: photo), options: [.atomic, .completeFileProtection])
    }

    func remove(_ photo: BodyPhoto) {
        try? FileManager.default.removeItem(at: url(for: photo))
    }

    /// Puts the staged photos in place and keeps the old ones aside, returning where they went, so
    /// the caller can `rollBack` if saving the matching records fails, or `discard` them once it
    /// has succeeded.
    func swapIn(_ staged: URL) throws -> URL {
        let previous = root.deletingLastPathComponent()
            .appendingPathComponent("Photos-previous-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.moveItem(at: root, to: previous)
        do {
            try FileManager.default.moveItem(at: staged, to: root)
        } catch {
            try? FileManager.default.moveItem(at: previous, to: root)
            throw error
        }
        return previous
    }

    func rollBack(_ previous: URL) {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.moveItem(at: previous, to: root)
    }

    func discard(_ previous: URL) {
        try? FileManager.default.removeItem(at: previous)
    }

    /// A scratch folder beside the photos, on the same volume so the final swap is a move.
    func makeStaging() throws -> URL {
        let staging = root.deletingLastPathComponent()
            .appendingPathComponent("Photos-staging-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        return staging
    }
}
