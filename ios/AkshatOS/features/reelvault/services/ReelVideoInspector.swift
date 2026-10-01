import AVFoundation

/// Says whether a copied file is a video this iPhone can play, and how long it runs.
protocol ReelVideoInspecting: Sendable {
    func duration(of url: URL) async throws -> Double
}

struct ReelVideoInspector: ReelVideoInspecting {
    func duration(of url: URL) async throws -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let (playable, duration) = try await asset.load(.isPlayable, .duration)
            let tracks = try await asset.loadTracks(withMediaType: .video)
            guard playable, !tracks.isEmpty, duration.seconds.isFinite, duration.seconds > 0 else {
                throw ReelVaultError.notAVideo
            }
            return duration.seconds
        } catch {
            throw ReelVaultError.notAVideo
        }
    }
}
