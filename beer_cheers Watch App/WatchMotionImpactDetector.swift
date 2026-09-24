//
//  WatchMotionImpactDetector.swift
//  beer_cheers Watch App
//
//  Accelerometer で手首の乾杯を検知する。
//  横（X）優先、縦（Y）・奥行き（Z）の誤反応を抑える。
//

import CoreMotion
import Foundation

@MainActor
final class WatchMotionImpactDetector {
    struct Configuration {
        var horizontalAxisDeltaG: Double = 0.18
        var horizontalAxisArmingDeltaG: Double = 0.12
        var verticalDeltaFloorG: Double = 0.28
        var verticalDominanceRatio: Double = 1.15
        var verticalWeight: Double = 0.25
        var depthDominanceRatio: Double = 1.25
        var depthDeltaFloorG: Double = 0.40
        var motionArmingDuration: TimeInterval = 2.0
        var startupIgnoreDuration: TimeInterval = 0.45
        var impactCooldown: TimeInterval = 0.70
        var updateInterval: TimeInterval = 1.0 / 30.0

        static let `default` = Configuration()
    }

    private struct Sample {
        var x: Double
        var y: Double
        var z: Double
    }

    private struct Delta {
        var horizontal: Double
        var vertical: Double
        var depth: Double
        var weightedLateral: Double
    }

    private let manager = CMMotionManager()
    private let deliveryQueue = OperationQueue.main
    private let configuration: Configuration

    private(set) var isRunning = false
    private var monitorStartedUptime: TimeInterval = 0
    private var lastImpactUptime: TimeInterval = 0
    private var lastSample: Sample?
    private var onImpact: (() -> Void)?
    private var onListening: ((Bool) -> Void)?

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    func start(onListening: ((Bool) -> Void)? = nil, onImpact: @escaping () -> Void) {
        stop()

        guard manager.isAccelerometerAvailable else {
            onListening?(false)
            return
        }

        self.onImpact = onImpact
        self.onListening = onListening
        monitorStartedUptime = ProcessInfo.processInfo.systemUptime
        lastImpactUptime = 0
        lastSample = nil

        manager.accelerometerUpdateInterval = configuration.updateInterval
        manager.startAccelerometerUpdates(to: deliveryQueue) { data, _ in
            guard let data else { return }
            let a = data.acceleration
            let sample = Sample(x: a.x, y: a.y, z: a.z)
            let now = ProcessInfo.processInfo.systemUptime
            Task { @MainActor [weak self] in
                self?.handle(sample: sample, now: now)
            }
        }

        isRunning = true
        onListening?(true)
    }

    func stop() {
        if manager.isAccelerometerActive {
            manager.stopAccelerometerUpdates()
        }
        isRunning = false
        lastSample = nil
        onImpact = nil
        onListening = nil
    }

    private func handle(sample: Sample, now t: TimeInterval) {
        guard isRunning else { return }

        if lastSample == nil {
            onListening?(true)
        }

        guard t - monitorStartedUptime >= configuration.startupIgnoreDuration else {
            lastSample = sample
            return
        }

        let previous = lastSample
        lastSample = sample
        guard let previous else { return }

        let delta = makeDelta(from: previous, to: sample)
        guard !shouldIgnore(delta) else { return }
        guard isImpact(delta, now: t) else { return }

        lastImpactUptime = t
        onImpact?()
    }

    private func makeDelta(from previous: Sample, to sample: Sample) -> Delta {
        let dx = sample.x - previous.x
        let dy = sample.y - previous.y
        let dz = sample.z - previous.z
        let weightedY = dy * configuration.verticalWeight
        return Delta(
            horizontal: abs(dx),
            vertical: abs(dy),
            depth: abs(dz),
            weightedLateral: sqrt(dx * dx + weightedY * weightedY)
        )
    }

    private func shouldIgnore(_ delta: Delta) -> Bool {
        let verticalDominant = delta.vertical >= configuration.verticalDeltaFloorG
            && delta.vertical > delta.horizontal * configuration.verticalDominanceRatio
        let depthDominant = delta.depth >= configuration.depthDeltaFloorG
            && delta.depth > delta.horizontal * configuration.depthDominanceRatio
        return verticalDominant || depthDominant
    }

    private func isImpact(_ delta: Delta, now t: TimeInterval) -> Bool {
        guard t - lastImpactUptime >= configuration.impactCooldown else { return false }

        let arming = t - monitorStartedUptime <= configuration.motionArmingDuration
        let horizontalLimit = arming
            ? configuration.horizontalAxisArmingDeltaG
            : configuration.horizontalAxisDeltaG

        let hitHorizontal = delta.horizontal >= horizontalLimit
        let hitWeighted = delta.weightedLateral >= horizontalLimit
            && delta.horizontal >= horizontalLimit * 0.55
        return hitHorizontal || hitWeighted
    }
}
