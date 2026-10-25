import Foundation
import SwiftUI
import UserNotifications

/// Watches this build's own signing expiry and warns before it runs out.
///
/// This is the replacement for the Windows health check in the case the Windows check cannot cover:
/// an app whose signing is refreshed by something other than Sideloadly. It reads the profile in
/// its own bundle, so it reports the truth whoever signed the app, and it needs no network, no
/// account and no companion machine.
///
/// It refreshes nothing itself. Like the Windows check, it only proves the state and says so — a
/// second signer racing the first would be worse than none.
@MainActor final class SigningExpiryService: ObservableObject {
    /// Registered in `AppNotificationCoordinator.featureNamespaces` so a tapped warning opens the
    /// backup screen, which is what you want to reach first when the app is about to stop launching.
    static let namespace = "akshatos.signing."

    @Published private(set) var state: SigningExpiry.State = .unknown
    @Published private(set) var expiry: Date?
    /// Set when warnings could not be scheduled, so the UI never implies a watch that is not running.
    @Published private(set) var scheduleFailed = false

    private let center: any PersonalNotificationCenter
    private let profileData: () -> Data?

    init(center: any PersonalNotificationCenter,
         profileData: @escaping () -> Data? = SigningExpiryService.bundledProfile) {
        self.center = center
        self.profileData = profileData
    }

    /// The profile Apple issued for this install. Absent in the simulator and in test hosts, which
    /// is why its absence is `unknown` rather than an error.
    static func bundledProfile() -> Data? {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision") else { return nil }
        return try? Data(contentsOf: url)
    }

    private var warningIdentifiers: [String] {
        [Self.namespace + "warning", Self.namespace + "final"]
    }

    /// Re-read the profile and re-arm the warnings. Safe to call on every foreground: it replaces
    /// its own requests rather than adding to them, and touches no other namespace.
    func refresh(now: Date = Date()) async {
        let expiry = profileData().flatMap { SigningExpiry.expiryDate(inProfile: $0) }
        self.expiry = expiry
        state = SigningExpiry.state(expiry: expiry, now: now)

        center.remove(warningIdentifiers)
        scheduleFailed = false

        guard let expiry else { return }
        // Never prompt for permission to deliver this. The reminders the user actually asked for own
        // that decision; a warning they did not opt into must not be the thing that demands access.
        guard await center.authorization() == .authorized else { return }

        let dates = SigningExpiry.warningDates(expiry: expiry, now: now)
        for (index, date) in dates.enumerated() where index < warningIdentifiers.count {
            let days = max(0, SigningExpiry.daysLeft(until: expiry, now: date))
            let content = UNMutableNotificationContent()
            content.title = "AkshatOS signing expires soon"
            content.body = days <= 1
                ? "The app stops opening tomorrow unless it is re-signed. Back up now if you have not."
                : "About \(days) days left before the app stops opening. Re-sign it when you can."
            // Passive: this is important but never urgent enough to light the screen mid-study.
            content.interruptionLevel = .passive
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(60, date.timeIntervalSince(now)), repeats: false)
            let request = UNNotificationRequest(
                identifier: warningIdentifiers[index], content: content, trigger: trigger)
            do { try await center.add(request) } catch { scheduleFailed = true }
        }
    }

    /// Plain words for the Settings row. Never claims health it has not established.
    var summary: String {
        switch state {
        case .unknown:
            return "Not known on this install"
        case .valid(let days):
            return "Signed for about \(days) more days"
        case .warning(let days):
            return "About \(days) days left — re-sign it soon"
        case .critical(let days):
            return days <= 0 ? "Expires today — re-sign it now" : "About \(days) days left — re-sign it now"
        case .expired(let days):
            return days <= 0 ? "Expired today" : "Expired \(days) days ago"
        }
    }
}

/// The signing row on the backup screen. Deliberately here: when the app is days from no longer
/// opening, the first useful action is a backup, and that is the screen this sits on.
struct SigningExpiryPanel: View {
    @ObservedObject var service: SigningExpiryService

    private var tint: Color {
        switch service.state {
        case .expired, .critical: return .red
        case .warning: return HubInk.seriesBest
        case .valid: return HubInk.support
        case .unknown: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "signature").foregroundStyle(tint)
                Text("Signing").font(.headline)
            }
            Text(service.summary).font(.subheadline).foregroundStyle(.secondary)
            if let expiry = service.expiry {
                Text("Signed until \(expiry.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if case .unknown = service.state {
                Text("No provisioning profile in this build, so its expiry cannot be read here.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if service.scheduleFailed {
                Text("Could not schedule the expiry warnings, so this is not being watched.")
                    .font(.caption).foregroundStyle(.red)
            }
            Text("Read from this build's own profile, so it is correct whichever tool re-signs it. "
                 + "It warns only; it never re-signs anything.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Signing. \(service.summary)")
    }
}
