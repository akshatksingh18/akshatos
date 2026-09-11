import Foundation

// Reading status. Pure Foundation logic, so the library's one-book-at-a-time rule is testable
// without a document, a store, or a device.
//
// Daily page goals, per-day reading records and the streak engine used to live here. They were
// removed at Akshat's request: the bookmark alone now signals reading, and nothing scores it.

enum PageVaultReadingStatus: String, Codable, CaseIterable {
    case wantToRead, reading, finished

    var label: String {
        switch self {
        case .wantToRead: return "Want to read"
        case .reading: return "Reading"
        case .finished: return "Finished"
        }
    }
}
