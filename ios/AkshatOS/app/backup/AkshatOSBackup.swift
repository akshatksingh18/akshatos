import Foundation

/// The index of a full AkshatOS backup: one folder holding every module's own backup side by side.
///
/// Each part is exactly the file or folder that module's own export produces, so a part copied out
/// of a full backup can still be restored from inside that module. The index only says which parts
/// are present and where; it never repeats their data. Parts are listed by the module's stable
/// `HubBackupPart.backupID`, so adding a module needs no change here.
struct AkshatOSBackupManifest: Codable, Equatable {
    static let fileName = "akshatos-backup.json"
    static let format = "akshatos-full-backup"
    static let currentVersion = 1

    struct Entry: Codable, Equatable {
        /// The module's `backupID`.
        var id: String
        /// The module's name when the backup was made, for messages about a part this build lacks.
        var title: String
        /// The file or folder inside the backup folder.
        var path: String
    }

    var format: String
    var version: Int
    var createdAt: Date
    var appVersion: String
    var parts: [Entry]

    init(createdAt: Date, appVersion: String, parts: [Entry]) {
        format = Self.format
        version = Self.currentVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.parts = parts
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Reads the version before the rest, so a backup from a newer build is reported as newer
    /// rather than as damaged. Every part must have a unique id and a plain name inside the folder.
    static func decode(_ data: Data) throws -> AkshatOSBackupManifest {
        struct Header: Decodable { var format: String?; var version: Int? }
        guard let header = try? JSONDecoder().decode(Header.self, from: data),
              header.format == format, let version = header.version else {
            throw AkshatOSBackupError.notABackup
        }
        guard version <= currentVersion else { throw AkshatOSBackupError.newerVersion }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(AkshatOSBackupManifest.self, from: data),
              manifest.version >= 1, !manifest.parts.isEmpty,
              Set(manifest.parts.map(\.id)).count == manifest.parts.count,
              Set(manifest.parts.map(\.path)).count == manifest.parts.count,
              manifest.parts.allSatisfy({ isPlainName($0.path) }) else {
            throw AkshatOSBackupError.notABackup
        }
        return manifest
    }

    /// One name inside the backup folder: no separators, no "." or "..", nothing hidden.
    static func isPlainName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && !name.contains("/") && !name.contains("\\")
            && name != fileName
    }

    /// The local date, formatted without a locale-dependent formatter.
    static func folderName(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "AkshatOS Backup %04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Module ids must be unique and non-empty, or two modules would claim one part of a backup.
    static func checkRegistry(_ ids: [String]) throws {
        guard ids.allSatisfy({ !$0.isEmpty }), Set(ids).count == ids.count else {
            throw AkshatOSBackupError.duplicateModule
        }
    }
}

enum AkshatOSBackupError: LocalizedError, Equatable {
    case notABackup
    case newerVersion
    case missingPart(String)
    case unknownPart(String)
    case invalidPart(String, reason: String)
    case storage(String)
    case duplicateModule

    var errorDescription: String? {
        switch self {
        case .notABackup:
            return "That folder is not an AkshatOS backup. Pick the folder named \"AkshatOS Backup\" and a date."
        case .newerVersion:
            return "That backup was made by a newer AkshatOS. Update the app first."
        case .missingPart(let title):
            return "The backup lists \(title), but its \(title) part is missing."
        case .unknownPart(let title):
            return "The backup has \(title), which this version of AkshatOS does not have. Update the app first."
        case .invalidPart(let title, let reason):
            return "The \(title) part of the backup cannot be restored: \(reason)"
        case .storage(let reason):
            return "The backup could not be made: \(reason)"
        case .duplicateModule:
            return "Two modules use the same backup name."
        }
    }
}
