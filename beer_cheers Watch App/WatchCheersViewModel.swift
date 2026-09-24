//
//  WatchCheersViewModel.swift
//  beer_cheers Watch App
//
//  乾杯演出・接続・加速度・Extended Runtime のオーケストレーション。
//

import Foundation
import Observation
import SwiftUI
import WatchKit

@MainActor
@Observable
final class WatchCheersViewModel {
    // MARK: - UI state

    private(set) var mugScale: CGFloat = 1
    private(set) var mugRotation: Double = 0
    private(set) var mugOffsetY: CGFloat = 0
    private(set) var captionVisible = false
    private(set) var isMotionAvailable = false
    private(set) var isSensingEnabled = true

    // MARK: - Private

    private var isAnimating = false
    private var didBootstrap = false
    private var lastSendUptime: TimeInterval = 0
    private let sendCooldown: TimeInterval = 0.55
    private let motionDetector = WatchMotionImpactDetector()

    // MARK: - Derived

    var idleCaption: String {
        if !isSensingEnabled { return "検知オフ" }
        return isMotionAvailable ? "振る／タップで乾杯" : "タップで乾杯"
    }

    var sensingToggleTitle: String {
        isSensingEnabled ? "検知オフ" : "検知オン"
    }

    // MARK: - Lifecycle

    /// 画面表示後に呼ぶ（起動直後の重い初期化を避ける）。
    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            CheersWatchConnectivity.shared.activate()
            guard isSensingEnabled else { return }

            try? await Task.sleep(for: .milliseconds(200))
            WatchExtendedRuntimeController.shared.startIfNeeded()

            try? await Task.sleep(for: .milliseconds(200))
            startMotion()
        }
    }

    func toggleSensing() {
        isSensingEnabled ? disableSensing() : enableSensing()
    }

    // MARK: - Cheers

    func cheers() {
        guard isSensingEnabled else {
            WKInterfaceDevice.current().play(.failure)
            return
        }

        emitCheersSignalIfNeeded()
        playMugAnimationIfNeeded()
    }

    // MARK: - Sensing

    private func enableSensing() {
        isSensingEnabled = true
        CheersWatchConnectivity.shared.activate()
        WatchExtendedRuntimeController.shared.startIfNeeded()
        startMotion()
        WKInterfaceDevice.current().play(.click)
    }

    private func disableSensing() {
        isSensingEnabled = false
        motionDetector.stop()
        isMotionAvailable = false
        WatchExtendedRuntimeController.shared.stop()
        WKInterfaceDevice.current().play(.stop)
    }

    private func startMotion() {
        guard isSensingEnabled else { return }
        motionDetector.start(
            onListening: { [weak self] listening in
                self?.isMotionAvailable = listening
            },
            onImpact: { [weak self] in
                self?.cheers()
            }
        )
    }

    /// 送信・振動はアニメーションと独立（スリープ中の isAnimating 固着対策）。
    private func emitCheersSignalIfNeeded() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastSendUptime >= sendCooldown else { return }
        lastSendUptime = now

        CheersWatchConnectivity.shared.activate()
        CheersWatchConnectivity.shared.sendCheers()
        WKInterfaceDevice.current().play(.success)
        WatchExtendedRuntimeController.shared.startIfNeeded()
    }

    private func playMugAnimationIfNeeded() {
        guard !isAnimating else { return }
        isAnimating = true
        captionVisible = true

        withAnimation(.interpolatingSpring(stiffness: 380, damping: 14)) {
            mugScale = 1.22
            mugRotation = 18
            mugOffsetY = -10
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 16)) {
                mugScale = 0.96
                mugRotation = -10
                mugOffsetY = 4
            }

            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 18)) {
                mugScale = 1
                mugRotation = 0
                mugOffsetY = 0
            }

            try? await Task.sleep(for: .milliseconds(450))
            captionVisible = false
            isAnimating = false
        }
    }
}
