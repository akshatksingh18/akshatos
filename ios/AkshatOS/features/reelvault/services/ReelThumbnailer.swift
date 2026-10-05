import AVFoundation

/// A still from each video for the library, so a row shows which video it is. Taken a moment in
/// rather than at the very first frame, which is often black, and kept in memory while the app runs.
@MainActor final class ReelThumbnailer {
    static let shared = ReelThumbnailer()
    private let cache = NSCache<NSURL, CGImage>()

    init() { cache.countLimit = 200 }

    func cached(_ url: URL) -> CGImage? { cache.object(forKey: url as NSURL) }

    /// Nil when the file cannot be read; the row then shows a placeholder.
    func thumbnail(for url: URL, maxPixels: CGFloat = 240) async -> CGImage? {
        if let image = cached(url) { return image }
        let image = await Self.generate(url, maxPixels: maxPixels)
        if let image { cache.setObject(image, forKey: url as NSURL) }
        return image
    }

    nonisolated static func generate(_ url: URL, maxPixels: CGFloat) async -> CGImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxPixels, height: maxPixels)
        let length = (try? await asset.load(.duration).seconds) ?? 0
        let moment = length.isFinite && length > 0 ? min(1, length / 2) : 0
        return try? await generator.image(at: CMTime(seconds: moment, preferredTimescale: 600)).image
    }
}
