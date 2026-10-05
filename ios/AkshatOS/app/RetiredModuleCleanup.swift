import Foundation

/// Deletes what a removed module left on the phone. ReelVault (Build 32) kept copied videos in
/// Application Support/ReelVault/ and its records in the ReelVault.store SwiftData files; Akshat
/// asked for it to be removed and its leftovers deleted, so they do not keep using storage. The
/// originals in Photos or Files were never touched. Runs at launch and is a no-op once nothing is
/// left, so it needs no flag.
enum RetiredModuleCleanup {
    static let reelVaultItems = ["ReelVault", "ReelVault.store", "ReelVault.store-shm", "ReelVault.store-wal"]

    /// The names it removed, for tests.
    @discardableResult
    static func run(in support: URL? = nil, fileManager: FileManager = .default) -> [String] {
        guard let support = support ?? fileManager.urls(for: .applicationSupportDirectory,
                                                        in: .userDomainMask).first else { return [] }
        return reelVaultItems.filter { name in
            let url = support.appendingPathComponent(name)
            guard fileManager.fileExists(atPath: url.path) else { return false }
            return (try? fileManager.removeItem(at: url)) != nil
        }
    }
}
