//
//  WatchExtendedRuntimeController.swift
//  beer_cheers Watch App
//
//  画面オフでもプロセスを落とさない Extended Runtime。
//  Info.plist: WKBackgroundModes = physical-therapy
//

import Foundation
import WatchKit

@MainActor
final class WatchExtendedRuntimeController: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = WatchExtendedRuntimeController()

    private var session: WKExtendedRuntimeSession?

    /// アプリが active なうちに呼ぶ。
    func startIfNeeded() {
        guard session == nil else { return }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        session = newSession
        newSession.start()
    }

    func stop() {
        session?.invalidate()
        session = nil
    }

    private func clearInvalidatedSession() {
        session = nil
    }

    // MARK: - WKExtendedRuntimeSessionDelegate

    nonisolated func extendedRuntimeSessionDidStart(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {}

    nonisolated func extendedRuntimeSessionWillExpire(
        _ extendedRuntimeSession: WKExtendedRuntimeSession
    ) {}

    nonisolated func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        Task { @MainActor in
            WatchExtendedRuntimeController.shared.clearInvalidatedSession()
        }
        #if DEBUG
            if let error {
                print("[WatchRuntime] invalidated \(reason.rawValue): \(error.localizedDescription)")
            }
        #endif
    }
}
