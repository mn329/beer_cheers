//
//  CheersPhoneConnectivity.swift
//  beer_cheers
//
//  Apple Watch からの乾杯通知を受け取り、iPhone 側の乾杯処理へ渡す。
//

import Foundation
import WatchConnectivity

@MainActor
final class CheersPhoneConnectivity: NSObject, WCSessionDelegate {
    static let shared = CheersPhoneConnectivity()

    /// Watch から乾杯が届いたときのコールバック。
    var onCheersFromWatch: (() -> Void)?

    private var didActivate = false

    func activate() {
        guard WCSession.isSupported(), !didActivate else { return }
        didActivate = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if DEBUG
            if let error {
                print("[PhoneCheers] activation error: \(error.localizedDescription)")
            }
        #endif
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncoming(message)
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncoming(userInfo)
    }

    private nonisolated func handleIncoming(_ message: [String: Any]) {
        guard let action = message["action"] as? String, action == "cheers" else { return }
        Task { @MainActor in
            CheersPhoneConnectivity.shared.onCheersFromWatch?()
        }
    }
}
