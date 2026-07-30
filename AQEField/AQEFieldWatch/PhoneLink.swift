import Foundation
import Observation
import WatchConnectivity

/// Watch side of the link. Sends a knock the instant it's tapped and mirrors
/// today's counts pushed from the phone.
///
/// Every knock is queued with `transferUserInfo` when the phone isn't
/// reachable, so logging works with the phone asleep in a pocket or out of
/// Bluetooth range — it syncs the moment they reconnect.
@Observable
final class PhoneLink: NSObject, WCSessionDelegate {
    var knocks = 0
    var conversations = 0
    var leads = 0
    var knockGoal = 100

    /// Knocks tapped on the wrist but not yet acknowledged by the phone.
    var pendingCount = 0

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func log(_ outcome: KnockOutcome) {
        let payload = ["outcome": outcome.code]
        // Optimistic local bump so the wrist feels instant.
        knocks += 1
        if outcome.isConversation { conversations += 1 }
        if outcome == .lead { leads += 1 }

        let session = WCSession.default
        guard session.activationState == .activated else {
            pendingCount += 1
            return
        }
        if session.isReachable {
            session.sendMessage(payload, replyHandler: { _ in }, errorHandler: { [weak self] _ in
                // Live send failed — fall back to the durable queue.
                session.transferUserInfo(payload)
                Task { @MainActor in self?.pendingCount += 1 }
            })
        } else {
            session.transferUserInfo(payload)
            pendingCount += 1
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        apply(session.receivedApplicationContext)
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        apply(context)
    }

    /// The phone finished taking a queued knock off our hands.
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer,
                 error: Error?) {
        guard error == nil else { return }
        Task { @MainActor in
            self.pendingCount = max(0, self.pendingCount - 1)
        }
    }

    /// Phone stats are authoritative — they include doors logged on the phone.
    private func apply(_ context: [String: Any]) {
        guard !context.isEmpty else { return }
        Task { @MainActor in
            if let value = context["knocks"] as? Int { self.knocks = value }
            if let value = context["conversations"] as? Int { self.conversations = value }
            if let value = context["leads"] as? Int { self.leads = value }
            if let value = context["knockGoal"] as? Int { self.knockGoal = value }
        }
    }
}
