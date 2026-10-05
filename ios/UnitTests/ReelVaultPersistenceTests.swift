import AVFoundation
import SwiftData
import XCTest
@testable import AkshatOS

/// Accepts any file that starts with the bytes "VIDEO", so storage, duplicates and backup can be
/// tested without encoding a real video for every case.
private struct MarkerInspector: ReelVideoInspecting {
    func duration(of url: URL) async throws -> Double {
        guard let data = try? Data(contentsOf: url), data.starts(with: Data("VIDEO".utf8)) else {
            throw ReelVaultError.notAVideo
        }
        return 7
    }
}

/// ReelVault against real files: copy-on-import, fingerprints, the shuffle, removal, and backup
/// into a library that never saw the videos. A separate container and file root per "phone".
@MainActor final class ReelVaultPersistenceTests: XCTestCase {
    private var sandbox: URL!
    private let clock = Date(timeIntervalSince1970: 1_790_000_000)

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("reelvault-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
    }

    private func makeContainer(_ name: String) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ReelVaultSchemaV1.self)
        return try ModelContainer(for: schema, migrationPlan: ReelVaultMigration.self,
                                  configurations: [ModelConfiguration(name, schema: schema, isStoredInMemoryOnly: true)])
    }

    private func makeStore(phone: String, container: ModelContainer? = nil,
                           real: Bool = false) throws -> ReelVaultStore {
        let inspector: any ReelVideoInspecting = real ? ReelVideoInspector() : MarkerInspector()
        let store = ReelVaultStore(
            repository: SwiftDataReelVaultRepository(container: try container ?? makeContainer(phone)),
            storage: try ReelVaultStorage(root: sandbox.appendingPathComponent(phone)),
            inspector: inspector, now: { [clock] in clock })
        store.load()
        return store
    }

    /// A stand-in video: the marker the test inspector accepts, then bytes that differ per name.
    private func makeClip(_ name: String, kind: String = "mp4") throws -> URL {
        let url = sandbox.appendingPathComponent("\(name).\(kind)")
        try (Data("VIDEO".utf8) + Data(name.utf8) + Data(repeating: 7, count: 2048)).write(to: url)
        return url
    }

    private func files(in phone: String, _ folder: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(
            atPath: sandbox.appendingPathComponent(phone).appendingPathComponent(folder).path)) ?? []
    }

    func testImportCopiesTheVideoAndItSurvivesReopeningAndLosingTheOriginal() async throws {
        let container = try makeContainer("PhoneA")
        let store = try makeStore(phone: "PhoneA", container: container)
        let source = try makeClip("squat")
        let original = try Data(contentsOf: source)
        guard case .success(let video) = await store.importVideo(from: source) else { return XCTFail("Import failed") }

        XCTAssertEqual(store.videos.map(\.id), [video.id])
        XCTAssertEqual(video.byteCount, Int64(original.count))
        XCTAssertEqual(video.duration, 7)
        XCTAssertTrue(ReelVault.isFingerprint(video.fingerprint))
        XCTAssertTrue(video.fileName.hasSuffix(".mp4"))
        try FileManager.default.removeItem(at: source)
        let copy = try XCTUnwrap(store.mediaURL(for: video), "The app's copy does not depend on the original")
        XCTAssertEqual(try Data(contentsOf: copy), original)
        XCTAssertTrue(files(in: "PhoneA", "Incoming").isEmpty, "Nothing is left in the scratch folder")

        let reopened = try makeStore(phone: "PhoneA", container: container)
        XCTAssertEqual(reopened.videos, store.videos, "The video was saved, not just shown")
    }

    func testTheSameVideoTwiceIsRefusedEvenWhenBothArriveAtOnce() async throws {
        let store = try makeStore(phone: "PhoneA")
        let source = try makeClip("deadlift")
        async let first = store.importVideo(from: source)
        async let second = store.importVideo(from: source)
        let results = await [first, second]
        XCTAssertEqual(results.filter { if case .success = $0 { return true } else { return false } }.count, 1)
        XCTAssertTrue(results.contains { $0 == .failure(.duplicate) })
        XCTAssertEqual(store.videos.count, 1)
        XCTAssertEqual(files(in: "PhoneA", "Media").count, 1, "Only one copy is kept")
        XCTAssertTrue(files(in: "PhoneA", "Incoming").isEmpty)
    }

    func testAFileThatIsNotAVideoIsRefusedAndLeavesNothingBehind() async throws {
        let store = try makeStore(phone: "PhoneA", real: true)
        let notes = sandbox.appendingPathComponent("notes.mp4")
        try Data("just some text pretending to be a video".utf8).write(to: notes)
        let result = await store.importVideo(from: notes)
        XCTAssertEqual(result, .failure(.notAVideo))
        XCTAssertTrue(store.videos.isEmpty)
        XCTAssertTrue(files(in: "PhoneA", "Media").isEmpty)
        XCTAssertTrue(files(in: "PhoneA", "Incoming").isEmpty)
    }

    func testARealVideoIsAcceptedWithItsLength() async throws {
        let store = try makeStore(phone: "PhoneA", real: true)
        let source = try await makeRealVideo(frames: 12)
        guard case .success(let video) = await store.importVideo(from: source) else {
            return XCTFail("A real H.264 video must be accepted")
        }
        XCTAssertEqual(video.duration, 1.2, accuracy: 0.3)
        let copy = try XCTUnwrap(store.mediaURL(for: video))

        let thumbnails = ReelThumbnailer()
        let still = await thumbnails.thumbnail(for: copy)
        XCTAssertNotNil(still, "The library shows a still of the video")
        XCTAssertLessThanOrEqual(max(still?.width ?? 0, still?.height ?? 0), 240, "Stills stay small")
        XCTAssertNotNil(thumbnails.cached(copy), "A still is made once and reused")
        let notVideo = try makeClip("not-a-video")
        let missing = await thumbnails.thumbnail(for: notVideo)
        XCTAssertNil(missing, "A file that is not a video gets the placeholder")
    }

    func testHeadlineIsCleanedSavedAndReloaded() async throws {
        let container = try makeContainer("PhoneA")
        let store = try makeStore(phone: "PhoneA", container: container)
        guard case .success(let video) = await store.importVideo(from: try makeClip("row")) else { return XCTFail() }
        XCTAssertEqual(video.headline, "", "A new video has no headline until one is written")
        store.setHeadline("  Seated row \n form check ", for: video.id)
        XCTAssertEqual(store.videos.first?.headline, "Seated row form check")
        let reopened = try makeStore(phone: "PhoneA", container: container)
        XCTAssertEqual(reopened.videos.first?.headline, "Seated row form check")
    }

    func testRemoveDeletesTheAppCopyAndNotTheOriginal() async throws {
        let store = try makeStore(phone: "PhoneA")
        let source = try makeClip("press")
        guard case .success(let video) = await store.importVideo(from: source) else { return XCTFail() }
        store.remove(video.id)
        XCTAssertTrue(store.videos.isEmpty)
        XCTAssertTrue(files(in: "PhoneA", "Media").isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path), "The original is never touched")
        XCTAssertNil(store.nextInFeed(), "An empty library has nothing to show")
    }

    func testTheFeedShowsEveryVideoOnceARoundAndNeverTwiceInARow() async throws {
        let store = try makeStore(phone: "PhoneA")
        for name in ["one", "two", "three", "four"] { await store.importVideo(from: try makeClip(name)) }
        XCTAssertEqual(store.videos.count, 4)
        let order = (0..<12).compactMap { _ in store.nextInFeed()?.id }
        XCTAssertEqual(order.count, 12)
        for round in 0..<3 {
            XCTAssertEqual(Set(order[(round * 4)..<(round * 4 + 4)]), Set(store.videos.map(\.id)))
        }
        XCTAssertTrue(zip(order, order.dropFirst()).allSatisfy { $0 != $1 })
    }

    func testBackupRestoresIntoAFreshLibraryWithHeadlines() async throws {
        let original = try makeStore(phone: "PhoneA")
        for name in ["alpha", "beta"] {
            guard case .success(let video) = await original.importVideo(from: try makeClip(name)) else { return XCTFail() }
            original.setHeadline("Headline \(name)", for: video.id)
        }
        let folder = try await original.stageBackup()
        XCTAssertTrue(folder.lastPathComponent.hasPrefix("ReelVault "))
        let manifest = try ReelVaultBackup.decode(
            Data(contentsOf: folder.appendingPathComponent(ReelVaultBackup.manifestName)))
        XCTAssertEqual(manifest.videos.count, 2)

        let container = try makeContainer("PhoneB")
        let fresh = try makeStore(phone: "PhoneB", container: container)
        let prepared = try fresh.prepareRestore(from: folder)
        XCTAssertEqual(prepared.plan.additions.count, 2)
        let summary = try await fresh.restore(prepared)
        XCTAssertEqual(summary, "2 videos added.")
        XCTAssertEqual(Set(fresh.videos.map(\.headline)), ["Headline alpha", "Headline beta"])
        for video in fresh.videos {
            let restored = try Data(contentsOf: try XCTUnwrap(fresh.mediaURL(for: video)))
            let source = try XCTUnwrap(original.videos.first { $0.fingerprint == video.fingerprint })
            XCTAssertEqual(restored, try Data(contentsOf: try XCTUnwrap(original.mediaURL(for: source))),
                           "The restored video is byte-identical")
        }
        let reopened = try makeStore(phone: "PhoneB", container: container)
        XCTAssertEqual(reopened.videos.count, 2, "The restore was saved, not only shown")

        XCTAssertThrowsError(try fresh.prepareRestore(from: folder)) {
            XCTAssertEqual($0 as? ReelVaultError, .nothingToRestore)
        }
        original.finishExport()
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testADamagedOrMissingVideoRestoresNothing() async throws {
        let original = try makeStore(phone: "PhoneA")
        for name in ["alpha", "beta"] { await original.importVideo(from: try makeClip(name)) }
        let folder = try await original.stageBackup()
        let media = folder.appendingPathComponent(ReelVaultBackup.mediaFolder)
        let victim = try XCTUnwrap(original.videos.last)
        try Data("VIDEO but altered".utf8).write(to: media.appendingPathComponent(victim.fileName))

        let fresh = try makeStore(phone: "PhoneB")
        let prepared = try fresh.prepareRestore(from: folder)
        do {
            _ = try await fresh.restore(prepared)
            XCTFail("A damaged video must stop the restore")
        } catch {
            guard case .damagedVideo? = error as? ReelVaultError else { return XCTFail("\(error)") }
        }
        XCTAssertTrue(fresh.videos.isEmpty, "Not even the good video was added")
        XCTAssertTrue(files(in: "PhoneB", "Media").isEmpty)
        XCTAssertTrue(files(in: "PhoneB", "Incoming").isEmpty)

        try FileManager.default.removeItem(at: media.appendingPathComponent(victim.fileName))
        XCTAssertThrowsError(try fresh.prepareRestore(from: folder)) {
            guard case .missingVideo? = $0 as? ReelVaultError else { return XCTFail("\($0)") }
        }
        XCTAssertThrowsError(try fresh.prepareRestore(from: sandbox)) {
            XCTAssertEqual($0 as? ReelVaultError, .notABackup)
        }
    }

    func testRestoringOntoAVideoAlreadyHereOnlyUpdatesItsHeadline() async throws {
        let original = try makeStore(phone: "PhoneA")
        let clip = try makeClip("alpha")
        guard case .success(let video) = await original.importVideo(from: clip) else { return XCTFail() }
        original.setHeadline("From the backup", for: video.id)
        let folder = try await original.stageBackup()

        let other = try makeStore(phone: "PhoneB")
        guard case .success(let mine) = await other.importVideo(from: clip) else { return XCTFail() }
        other.setHeadline("Written here", for: mine.id)
        let prepared = try other.prepareRestore(from: folder)
        let summary = try await other.restore(prepared)
        XCTAssertEqual(summary, "1 headline updated.")
        XCTAssertEqual(other.videos.map(\.id), [mine.id], "No second copy is added")
        XCTAssertEqual(other.videos.first?.headline, "From the backup")
        XCTAssertEqual(files(in: "PhoneB", "Media").count, 1)
    }

    func testTheHubFullBackupCarriesReelVault() async throws {
        let original = try makeStore(phone: "PhoneA")
        guard case .success(let video) = await original.importVideo(from: try makeClip("alpha")) else { return XCTFail() }
        original.setHeadline("Kept", for: video.id)
        let hub = FullBackupService(parts: [original], now: { [clock] in clock }, appVersion: "test",
                                    scratch: sandbox.appendingPathComponent("HubOut"))
        let folder = try await hub.prepareExport()
        let index = try AkshatOSBackupManifest.decode(
            Data(contentsOf: folder.appendingPathComponent(AkshatOSBackupManifest.fileName)))
        XCTAssertEqual(index.parts.map(\.id), ["reelVault"])
        XCTAssertEqual(index.parts.map(\.path), ["reelvault"])

        let fresh = try makeStore(phone: "PhoneB")
        let freshHub = FullBackupService(parts: [fresh], appVersion: "test",
                                         scratch: sandbox.appendingPathComponent("HubIn"))
        let prepared = try await freshHub.prepareRestore(from: folder)
        let summary = await freshHub.restore(prepared)
        XCTAssertEqual(summary, "Restored: ReelVault.")
        XCTAssertEqual(fresh.videos.map(\.headline), ["Kept"])
        XCTAssertNotNil(fresh.videos.first.flatMap(fresh.mediaURL(for:)))
    }

    /// A short real H.264 file, so the real inspector is proven against what iPhones record.
    private func makeRealVideo(frames: Int) async throws -> URL {
        let url = sandbox.appendingPathComponent("real-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64
        ])
        writer.add(input)
        XCTAssertTrue(writer.startWriting(), "\(String(describing: writer.error))")
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 5_000_000) }
            var created: CVPixelBuffer?
            CVPixelBufferCreate(nil, 64, 64, kCVPixelFormatType_32BGRA, nil, &created)
            let buffer = try XCTUnwrap(created)
            CVPixelBufferLockBaseAddress(buffer, [])
            memset(CVPixelBufferGetBaseAddress(buffer), Int32(40 + frame * 10), CVPixelBufferGetDataSize(buffer))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 10)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "\(String(describing: writer.error))")
        return url
    }
}
