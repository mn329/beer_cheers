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

    private let lock = NSLock()
    private var didActivate = false

    func activate() {
        lock.lock()
        defer { lock.unlock() }
        guard WCSession.isSupported(), !didActivate else { return }
        didActivate = true
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func sendCheers() {
        activate()
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        let payload = WatchCheersPayload.makeCheersMessage()

        // スリープ中は isReachable になりにくい。即時送信できるときだけ sendMessage、
        // 失敗時／非到達時は transferUserInfo に一本化する（二重送信しない）。
        if session.activationState == .activated, session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    nonisolated func session(
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
