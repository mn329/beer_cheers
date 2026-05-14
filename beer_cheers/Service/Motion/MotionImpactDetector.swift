//
//  MotionImpactDetector.swift
//  beer_cheers
//
//  CoreMotion の Device Motion（userAcceleration）から
//  「乾杯」相当の衝撃を検知し、コールバックで通知する。
//
//  ・アーム期間（起動直後）は閾値を下げる
//  ・クールダウンで連打を抑制
//  ・systemUptime ベースで時間計測（経過時間が単調増加）
//

import CoreMotion
import Foundation

@MainActor
final class MotionImpactDetector {
    struct Configuration {
        /// 通常時の衝撃閾値（G）
        var impactThresholdG: Double = 2.4
        /// アーム期間中のゆるめの閾値（G）
        var impactThresholdArmingG: Double = 1.75
        /// アーム期間の長さ（秒）
        var motionArmingDuration: TimeInterval = 2.8
        /// 連続検知を抑えるクールダウン（秒）
        var impactCooldown: TimeInterval = 0.42

        static let `default` = Configuration()
    }

    private let manager = CMMotionManager()
    private let deliveryQueue = OperationQueue.main
    private let configuration: Configuration

    private(set) var isRunning = false
    /// 端末で Device Motion が使えるか
    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    private var monitorStartedUptime: TimeInterval = 0
    private var samplesIgnoredUntilUptime: TimeInterval = 0
    private var didStartArmingClock = false
    private var lastImpactUptime: TimeInterval = 0

    private var onImpact: (@MainActor () -> Void)?

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    func start(onImpact: @escaping @MainActor () -> Void) {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        self.onImpact = onImpact
        didStartArmingClock = false
        // 未指定だと端末により高頻度（例: 60Hz 前後）でメインキューに届き、描画と競合してカクつきやすい
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: deliveryQueue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let t = ProcessInfo.processInfo.systemUptime
            guard t >= self.samplesIgnoredUntilUptime else { return }
            if !self.didStartArmingClock {
                self.didStartArmingClock = true
                self.monitorStartedUptime = t
            }
            let ua = motion.userAcceleration
            let magnitude = sqrt(ua.x * ua.x + ua.y * ua.y + ua.z * ua.z)
            guard magnitude >= self.currentThresholdG(now: t) else { return }
            self.evaluateImpact(now: t)
        }
        isRunning = true
    }

    func stop() {
        if manager.isDeviceMotionActive {
            manager.stopDeviceMotionUpdates()
        }
        isRunning = false
        didStartArmingClock = false
        onImpact = nil
    }

    private func currentThresholdG(now t: TimeInterval) -> Double {
        let elapsed = t - monitorStartedUptime
        return elapsed <= configuration.motionArmingDuration
            ? configuration.impactThresholdArmingG
            : configuration.impactThresholdG
    }

    private func evaluateImpact(now t: TimeInterval) {
        guard t - lastImpactUptime >= configuration.impactCooldown else { return }
        lastImpactUptime = t
        onImpact?()
    }
}
