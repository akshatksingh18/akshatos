import Foundation

/// What a module does to take part in the hub's full backup.
///
/// Every module in `features/` conforms, usually with an extension on its store in
/// `<Feature>BackupPart.swift`, and is listed once in the app's service list. `check-backup-coverage.py`
/// fails CI when a module has no conformance or is not listed, so a new module cannot quietly be
/// left out of Back up everything. `hub-plan.md` § Full backup owns the contract.
@MainActor protocol HubBackupPart: AnyObject {
    /// Stable identifier written into every backup. Never change it once shipped: an older backup
    /// finds its part by this id.
    var backupID: String { get }
    /// Shown to the user, such as "Lift Log".
    var backupTitle: String { get }
    /// Writes this module's own backup into `folder` as one file or folder, and returns that item's
    /// name. Returns nil when there is nothing to back up; throws when the data cannot be read.
    func writeBackup(into folder: URL) async throws -> String?
    /// Reads and checks the item this module wrote, changing nothing. The returned restore is only
    /// applied once every part of the backup has passed its check.
    func prepareBackupRestore(from item: URL) async throws -> HubBackupRestore
}

/// A checked part, ready to apply after the user confirms.
struct HubBackupRestore {
    /// Said once after a successful restore, such as what the user needs to switch back on.
    let note: String?
    let apply: @MainActor () async -> HubBackupOutcome

    init(note: String? = nil, apply: @escaping @MainActor () async -> HubBackupOutcome) {
        self.note = note
        self.apply = apply
    }

    /// A part that is already on the phone exactly as backed up.
    static var alreadyCurrent: HubBackupRestore { HubBackupRestore { .alreadyCurrent } }
}

enum HubBackupOutcome: Equatable {
    case restored
    case alreadyCurrent
    case failed(String)
}
