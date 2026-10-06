import XCTest
@testable import AkshatOS

/// The natural voice's import and fallback, without a real model: CI has no 350 MB Kokoro folder,
/// so rendering itself is a phone check (the Voices screen's speed test).
@MainActor final class PageVaultNaturalVoiceTests: XCTestCase {
    private var sandbox: URL!
    private var suite: String!

    override func setUpWithError() throws {
        sandbox = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pagevault-natural-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
        suite = "pagevault-natural-\(UUID().uuidString)"
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: sandbox)
        UserDefaults().removePersistentDomain(forName: suite)
    }

    /// A folder shaped like the Kokoro download, with placeholder contents.
    private func makeVoiceFolder(leaving out: String? = nil) throws -> URL {
        let folder = sandbox.appendingPathComponent("kokoro-int8-multi-lang-v1_0", isDirectory: true)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("espeak-ng-data/voices"),
                                                withIntermediateDirectories: true)
        try Data("phonemes".utf8).write(to: folder.appendingPathComponent("espeak-ng-data/voices/en"))
        for name in ["model.onnx", "voices.bin", "tokens.txt", "lexicon-us-en.txt", "README.md"] where name != out {
            try Data(name.utf8).write(to: folder.appendingPathComponent(name))
        }
        if out == "espeak-ng-data" {
            try FileManager.default.removeItem(at: folder.appendingPathComponent("espeak-ng-data"))
        }
        return folder
    }

    func testAFolderMissingPartsIsRefusedAndNamesThem() throws {
        let voice = PageVaultNaturalVoice(folder: sandbox.appendingPathComponent("installed"))
        let folder = try makeVoiceFolder(leaving: "voices.bin")
        XCTAssertThrowsError(try voice.importVoice(from: folder)) { error in
            XCTAssertTrue(error.localizedDescription.contains("voices.bin"), error.localizedDescription)
        }
        XCTAssertFalse(voice.isInstalled, "Nothing is installed from an incomplete folder")
    }

    func testAKokoroFolderIsCopiedWholeAndCanBeRemoved() throws {
        let installed = sandbox.appendingPathComponent("installed")
        let voice = PageVaultNaturalVoice(folder: installed)
        try voice.importVoice(from: try makeVoiceFolder())
        XCTAssertTrue(voice.isInstalled)
        XCTAssertTrue(FileManager.default.fileExists(atPath: installed.appendingPathComponent("espeak-ng-data/voices/en").path),
                      "Nested data is copied too")
        XCTAssertGreaterThan(voice.installedBytes, 0)
        XCTAssertEqual(try installed.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true,
                       "The voice can be imported again, so it stays out of the phone's backup")
        try voice.importVoice(from: try makeVoiceFolder())
        XCTAssertTrue(voice.isInstalled, "Importing again replaces the voice")
        voice.remove()
        XCTAssertFalse(voice.isInstalled)
    }

    func testWithoutAnInstalledVoiceReadingUsesTheIPhoneVoice() throws {
        let voice = PageVaultNaturalVoice(folder: sandbox.appendingPathComponent("none"))
        let narrator = PageVaultNarrator(url: sandbox.appendingPathComponent("book.pdf"), title: "Book",
                                         pageCount: 1, defaults: UserDefaults(suiteName: suite)!,
                                         naturalVoice: voice)
        XCTAssertFalse(narrator.naturalVoiceOn, "Off until chosen")
        narrator.naturalVoiceOn = true
        XCTAssertFalse(narrator.usesNaturalVoice, "Chosen but not installed: the iPhone voice reads")
        XCTAssertEqual(narrator.naturalSpeaker, PageVaultNaturalVoiceRules.defaultSpeaker)
        narrator.naturalSpeaker = 16
        let reopened = PageVaultNarrator(url: sandbox.appendingPathComponent("book.pdf"), title: "Book",
                                         pageCount: 1, defaults: UserDefaults(suiteName: suite)!,
                                         naturalVoice: voice)
        XCTAssertTrue(reopened.naturalVoiceOn, "The choice is remembered")
        XCTAssertEqual(reopened.naturalSpeaker, 16)
    }
}
