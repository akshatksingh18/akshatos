import Foundation

/// One PDF as it appeared in the linked inbox folder. It is recognised by what a folder listing can
/// report cheaply — name, size and modification second — so a pass never reads or hashes a file it
/// has already dealt with.
struct PageVaultInboxFile: Codable, Hashable, Sendable {
    var name: String
    var byteCount: Int64
    /// Whole seconds: a file provider is not guaranteed to report sub-second times identically twice.
    var modifiedSecond: Int64?

    init(name: String, byteCount: Int64, modifiedAt: Date?) {
        self.name = name
        self.byteCount = byteCount
        self.modifiedSecond = modifiedAt.map { Int64($0.timeIntervalSince1970.rounded(.down)) }
    }
}

/// The linked folder and the files already dealt with, stored by the data layer as one small file.
struct PageVaultInboxState: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version = PageVaultInboxState.currentVersion
    /// The system's bookmark for the folder the user picked, which is what keeps access to it.
    var bookmark: Data
    var folderName: String
    var linkedAt: Date
    var settled: [PageVaultInboxFile] = []
}

/// What happened to one inbox file on one pass.
enum PageVaultInboxOutcome: Equatable, Sendable {
    case added(title: String)
    case alreadyInLibrary
    /// The file itself is the problem — not a PDF, locked, empty. Retrying cannot help.
    case rejected(name: String, reason: String)
    /// Something around the file failed — a download, space, the provider. The next pass retries it.
    case deferred(name: String, reason: String)

    /// Settled files are remembered and never tried again while they stay unchanged in the folder.
    var settles: Bool {
        if case .deferred = self { return false }
        return true
    }
}

/// One pass over the inbox folder, told the way the library shows it.
struct PageVaultInboxReport: Equatable, Sendable {
    var checkedAt: Date
    var added: [String] = []
    var alreadyInLibrary = 0
    var rejected: [String] = []
    var deferred: [String] = []

    mutating func record(_ outcome: PageVaultInboxOutcome) {
        switch outcome {
        case .added(let title): added.append(title)
        case .alreadyInLibrary: alreadyInLibrary += 1
        case .rejected(let name, let reason): rejected.append("\(name): \(reason)")
        case .deferred(let name, let reason): deferred.append("\(name): \(reason)")
        }
    }

    /// Only additions and problems are news. A pass that found nothing new says so plainly.
    var summary: String {
        var parts: [String] = []
        if added.count == 1, let title = added.first {
            parts.append("Added \"\(title)\".")
        } else if !added.isEmpty {
            parts.append("Added \(added.count) books.")
        }
        if !rejected.isEmpty {
            parts.append(rejected.count == 1 ? "1 file could not be added."
                                             : "\(rejected.count) files could not be added.")
        }
        if !deferred.isEmpty {
            parts.append(deferred.count == 1 ? "1 file will be tried again."
                                             : "\(deferred.count) files will be tried again.")
        }
        return parts.isEmpty ? "Nothing new." : parts.joined(separator: " ")
    }

    /// Worth showing in the library itself, rather than only in the inbox sheet.
    var isNews: Bool { !added.isEmpty || !rejected.isEmpty || !deferred.isEmpty }
}

enum PageVaultInbox {
    private static let placeholderSuffix = ".icloud"

    /// The PDF a listed folder entry stands for, or nil when it is not one to import. Only top-level
    /// `.pdf` files count. iCloud Drive lists a file it has not downloaded yet as a hidden
    /// `.Name.pdf.icloud` placeholder; that stands for `Name.pdf`, which a coordinated read fetches.
    static func pdfName(forListed name: String) -> String? {
        var candidate = name
        if candidate.hasPrefix("."), candidate.hasSuffix(placeholderSuffix) {
            candidate = String(candidate.dropFirst().dropLast(placeholderSuffix.count))
        } else if candidate.hasPrefix(".") {
            return nil
        }
        guard candidate.count > 4, candidate.lowercased().hasSuffix(".pdf") else { return nil }
        return candidate
    }

    /// Files to try this pass: listed, not already settled, one per name, in a stable order.
    static func pending(_ listed: [PageVaultInboxFile],
                        settled: [PageVaultInboxFile]) -> [PageVaultInboxFile] {
        let done = Set(settled)
        var seen: Set<String> = []
        return listed
            .filter { !done.contains($0) && seen.insert($0.name).inserted }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// What to remember after a pass: every settled file still in the folder, old or new. A file that
    /// has left the folder is forgotten, so the record never grows beyond what the folder holds.
    static func settled(previous: [PageVaultInboxFile], newlySettled: [PageVaultInboxFile],
                        listed: [PageVaultInboxFile]) -> [PageVaultInboxFile] {
        let present = Set(listed)
        var kept: [PageVaultInboxFile] = []
        var seen: Set<PageVaultInboxFile> = []
        for file in previous + newlySettled where present.contains(file) && seen.insert(file).inserted {
            kept.append(file)
        }
        return kept
    }

    /// Sorts an import failure into one the file will always hit and one worth retrying.
    static func outcome(for failure: PageVaultImportFailure, name: String) -> PageVaultInboxOutcome {
        switch failure {
        case .duplicate:
            return .alreadyInLibrary
        case .storage(let reason):
            return .deferred(name: name, reason: reason)
        case .unreadable, .passwordProtected, .noPages:
            return .rejected(name: name, reason: failure.message)
        }
    }
}
