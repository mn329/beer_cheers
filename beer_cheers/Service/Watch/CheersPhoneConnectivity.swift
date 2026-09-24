//
//  CheersPhoneConnectivity.swift
//  beer_cheers
//
//  Apple Watch からの乾杯通知を受け取り、iPhone 側の乾杯処理へ渡す。
//  ペイロードキーは Watch 側 WatchCheersPayload と一致させること。
//

import Foundation
import WatchConnectivity

@MainActor
final class CheersPhoneConnectivity: NSObject, WCSessionDelegate {
    static let shared = CheersPhoneConnectivity()

    /// Watch 側 WatchCheersPayload と同じキー。
    private enum Payload {
        nonisolated static let actionKey = "action"
        nonisolated static let cheersAction = "cheers"
    }

    var onCheersFromWatch: (() -> Void)?

    private var didActivate = false
    private var lastHandledCheersUptime: TimeInterval = 0
    private let cheersDebounce: TimeInterval = 0.45

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
        guard let action = message[Payload.actionKey] as? String,
              action == Payload.cheersAction
        else { return }

        Task { @MainActor in
            let bridge = CheersPhoneConnectivity.shared
            let now = ProcessInfo.processInfo.systemUptime
            guard now - bridge.lastHandledCheersUptime >= bridge.cheersDebounce else { return }
            bridge.lastHandledCheersUptime = now
            bridge.onCheersFromWatch?()
        }
    }
}
