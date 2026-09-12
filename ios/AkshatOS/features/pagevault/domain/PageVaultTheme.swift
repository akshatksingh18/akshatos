import Foundation

// How the page is tinted. Sepia is the default: Akshat chose it over the warmer white after reading
// on it, and the separate "warm" theme was removed rather than kept as a near-duplicate.
//
// The raw values are what an installed build writes to disk, so they must not be renamed.

enum PageVaultTheme: String, Codable, CaseIterable {
    /// The page exactly as published.
    case paper
    /// An older-paper tone, and the default.
    case sepia
    /// Inverted: light text on a dark page.
    case night

    static let `default` = PageVaultTheme.sepia

    var label: String {
        switch self {
        case .paper: return "Paper"
        case .sepia: return "Sepia"
        case .night: return "Night"
        }
    }

    /// Night is the only theme that inverts the page; the rest tint it.
    var inverts: Bool { self == .night }

    /// A value stored by an earlier build falls back instead of failing. Build 21 had a separate
    /// "warm" theme, so anyone who chose it lands on sepia rather than losing their choice.
    static func stored(_ raw: String?) -> PageVaultTheme {
        guard let raw else { return .default }
        if let theme = PageVaultTheme(rawValue: raw) { return theme }
        return raw == "warm" ? .sepia : .default
    }
}
