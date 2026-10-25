import Foundation

/// How long this installed build stays signed, read from the provisioning profile Apple issued when
/// it was installed.
///
/// Signing is refreshed by something outside the app — Sideloadly's daemon on a Windows machine
/// today, possibly SideStore on the phone later — and whoever does it, the app stops launching when
/// the profile expires. The Windows health check can only read Sideloadly's own database, so an app
/// refreshed by anything else would expire unwatched, which is exactly how the retired Squat
/// Reminder registration reached expiry with nothing recorded against it.
///
/// The profile inside the bundle is the one source that is true regardless of who signed it, needs
/// no network, no account and no companion machine, and is readable by the app itself. That makes
/// it the only monitor that survives a change of signer.
///
/// Foundation only, no bundle or notification access, so every rule here is testable from synthetic
/// data.
enum SigningExpiry {
    /// Mirrors the Windows health check's thresholds so the phone and the laptop never disagree
    /// about how urgent the same expiry is. `setup.md` owns the Windows side.
    static let warningDays = 3
    static let criticalDays = 2

    enum State: Equatable {
        /// No profile in the bundle: a simulator run, or a build that was not signed this way.
        /// Reported honestly rather than as healthy — an unknown expiry is not a safe one.
        case unknown
        case valid(daysLeft: Int)
        case warning(daysLeft: Int)
        case critical(daysLeft: Int)
        case expired(daysAgo: Int)

        /// Whether this state is worth interrupting for. `unknown` is not: it is the normal state
        /// in the simulator and during tests, and crying wolf there would train the alert away.
        var needsAttention: Bool {
            switch self {
            case .warning, .critical, .expired: return true
            case .valid, .unknown: return false
            }
        }
    }

    /// A provisioning profile is a CMS-signed container with a plain XML property list inside it.
    /// Rather than decode the signature — which would need Security framework work to prove nothing
    /// useful, since the file is already inside our own signed bundle — take the plist by its
    /// documented delimiters.
    static func plistData(inProfile data: Data) -> Data? {
        let opening = Data("<?xml".utf8), closing = Data("</plist>".utf8)
        guard let start = data.range(of: opening),
              let end = data.range(of: closing, options: [], in: start.lowerBound..<data.endIndex)
        else { return nil }
        return data.subdata(in: start.lowerBound..<end.upperBound)
    }

    /// The profile's expiry, or nil when the data is not a profile, is truncated, or carries no
    /// usable `ExpirationDate`. Never guesses a date.
    static func expiryDate(inProfile data: Data) -> Date? {
        guard let plist = plistData(inProfile: data),
              let parsed = try? PropertyListSerialization.propertyList(from: plist, options: [], format: nil),
              let fields = parsed as? [String: Any]
        else { return nil }
        return fields["ExpirationDate"] as? Date
    }

    /// Whole days remaining, rounded **down**, so a profile with 2.9 days left reports 2 and is
    /// treated as critical. Rounding the other way would delay the alarm past the point where the
    /// refresh buffer still has room.
    static func daysLeft(until expiry: Date, now: Date) -> Int {
        Int((expiry.timeIntervalSince(now) / 86_400).rounded(.down))
    }

    static func state(expiry: Date?, now: Date) -> State {
        guard let expiry else { return .unknown }
        guard expiry > now else {
            let ago = Int((now.timeIntervalSince(expiry) / 86_400).rounded(.down))
            return .expired(daysAgo: max(0, ago))
        }
        let days = daysLeft(until: expiry, now: now)
        if days <= criticalDays { return .critical(daysLeft: days) }
        if days <= warningDays { return .warning(daysLeft: days) }
        return .valid(daysLeft: days)
    }

    /// When to warn, ahead of a known expiry. Two points only: one while there is still room for a
    /// refresh to be retried, and one last call. Anything already in the past is dropped rather than
    /// delivered immediately, because an alert about a deadline that has passed is noise.
    static func warningDates(expiry: Date, now: Date) -> [Date] {
        [Double(warningDays), 1.0]
            .map { expiry.addingTimeInterval(-$0 * 86_400) }
            .filter { $0 > now }
    }
}
