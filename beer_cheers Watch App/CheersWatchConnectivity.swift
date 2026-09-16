//
//  CheersWatchConnectivity.swift
//  beer_cheers Watch App
//
//  Watch → iPhone へ乾杯イベントを送る。
//

import Foundation
import WatchConnectivity

final class CheersWatchConnectivity: NSObject, WCSessionDelegate {
    static let shared = CheersWatchConnectivity()

    static let actionKey = "action"
    static let cheersAction = "cheers"

    private var didActivate = false

    func activate() {
        guard WCSession.isSupported(), !didActivate else { return }
        didActivate = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendCheers() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload = [Self.actionKey: Self.cheersAction]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                #if DEBUG
                    print("[WatchCheers] sendMessage failed: \(error.localizedDescription)")
                #endif
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: - WCSessionDelegate

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        #if DEBUG
            if let error {
                print("[WatchCheers] activation error: \(error.localizedDescription)")
            }
        #endif
    }
}
