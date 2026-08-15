import Foundation
import Observation
import WatchConnectivity

/// iPhone side of the Watch link. Receives knocks logged on the wrist and
/// pushes today's counts back so the watch face stays current.
///
/// Knocks arrive either as a live message (watch + phone both awake) or as
/// queued user info (phone asleep in a pocket — delivered on next wake), so
/// nothing is lost mid-street.
@Observable
final class WatchLink: NSObject, WCSessionDelegate {
    /// One session per app; the store pushes stat updates through it.
    static let shared = WatchLink()

    /// Set by the app root; called on the main actor for every watch knock.
    var onKnock: ((KnockOutcome) -> Void)?

    private(set) var isWatchAppInstalled = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Push today's numbers to the watch (cheap, coalesced by the system).
    func sendTodayStats(_ stats: DayStats, goals: DailyGoals) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        try? session.updateApplicationContext([
            "knocks": stats.knocks,
            "conversations": stats.conversations,
            "leads": stats.leads,
            "knockGoal": goals.knocks,
        ])
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so a switched watch keeps working.
        WCSession.default.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchAppInstalled = session.isWatchAppInstalled
        }
    }

    /// Live path: watch is reachable and waiting on a reply.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        handle(message)
        replyHandler(["ok": true])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handle(message)
    }

    /// Queued path: delivered when the phone next wakes.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handle(userInfo)
    }

    private func handle(_ payload: [String: Any]) {
        guard let code = payload["outcome"] as? String,
              let outcome = KnockOutcome(code: code) else { return }
        Task { @MainActor in
            self.onKnock?(outcome)
        }
    }
}
