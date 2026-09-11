import Foundation

// How the page is tinted. Warm paper was the only choice at first; sepia and night were added
// because a white page is unpleasant to read at night.
//
// The raw values are what an installed build writes to disk, so they must not be renamed.

enum PageVaultTheme: String, Codable, CaseIterable {
    /// The page exactly as published.
    case paper
    /// A gentle warm white — the default, because this is meant to read like a book.
    case warm
    /// A deeper, older-paper tone.
    case sepia
    /// Inverted: light text on a dark page.
    case night

    static let `default` = PageVaultTheme.warm

    var label: String {
        switch self {
        case .paper: return "Paper"
        case .warm: return "Warm"
        case .sepia: return "Sepia"
        case .night: return "Night"
        }
    }

    /// Night is the only theme that inverts the page; the rest tint it.
    var inverts: Bool { self == .night }

    /// A value stored by a build that did not know this theme falls back instead of failing.
    static func stored(_ raw: String?) -> PageVaultTheme {
        guard let raw, let theme = PageVaultTheme(rawValue: raw) else { return .default }
        return theme
    }
}
