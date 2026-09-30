import Foundation

/// The index of a full AkshatOS backup: one folder holding every module's own backup side by side.
///
/// Each part is exactly the file or folder that module's own export produces, so a part copied out
/// of a full backup can still be restored from inside that module. This file only says which parts
/// are present; it never repeats their data.
struct AkshatOSBackupManifest: Codable, Equatable {
    static let fileName = "akshatos-backup.json"
    static let format = "akshatos-full-backup"
    static let currentVersion = 1

    enum Part: String, Codable, CaseIterable {
        case pushups, pageVault, liftLog, body

        /// Where the part sits inside the backup folder.
        var path: String {
            switch self {
            case .pushups: return "pushups.json"
            case .pageVault: return "pagevault"
            case .liftLog: return "lift-log.json"
            case .body: return "body"
            }
        }

        var title: String {
            switch self {
            case .pushups: return "Pushups"
            case .pageVault: return "PageVault"
            case .liftLog: return "Lift Log"
            case .body: return "Body"
            }
        }
    }

    var format: String
    var version: Int
    var createdAt: Date
    var appVersion: String
    var parts: [Part]

    init(createdAt: Date, appVersion: String, parts: [Part]) {
        format = Self.format
        version = Self.currentVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.parts = Part.allCases.filter(parts.contains)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Reads the version before the rest, so a backup from a newer build is reported as newer
    /// rather than as damaged.
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
              Set(manifest.parts).count == manifest.parts.count else {
            throw AkshatOSBackupError.notABackup
        }
        return manifest
    }

    /// The local date, formatted without a locale-dependent formatter.
    static func folderName(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "AkshatOS Backup %04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

enum AkshatOSBackupError: LocalizedError, Equatable {
    case notABackup
    case newerVersion
    case missingPart(String)
    case invalidPart(String, reason: String)
    case storage(String)

    var errorDescription: String? {
        switch self {
        case .notABackup:
            return "That folder is not an AkshatOS backup. Pick the folder named \"AkshatOS Backup\" and a date."
        case .newerVersion:
            return "That backup was made by a newer AkshatOS. Update the app first."
        case .missingPart(let title):
            return "The backup lists \(title), but its \(title) part is missing."
        case .invalidPart(let title, let reason):
            return "The \(title) part of the backup cannot be restored: \(reason)"
        case .storage(let reason):
            return "The backup could not be made: \(reason)"
        }
    }
}
