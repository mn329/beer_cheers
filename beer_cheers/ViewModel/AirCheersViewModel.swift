//
//  AirCheersViewModel.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/04/26.
//

import AVFoundation
import CoreMotion
import FirebaseCore
import FirebaseDatabase
import Observation
import SwiftUI
import UIKit

// MARK: - ViewModel（CoreMotion・音声・ハプティクス・Realtime DB）

@MainActor
@Observable
final class AirCheersViewModel {
    /// userAcceleration の合成ベクトルがこの値（G）を超えたら乾杯とみなす
    private let impactThresholdG: Double = 2.4

    /// モーション開始直後はセンサーが落ち着くまで閾値をさらに下げる
    private let impactThresholdArmingG: Double = 1.75
    private let motionArmingDuration: TimeInterval = 2.8

    /// 連続検知を防ぐクールダウン（秒）
    private let impactCooldown: TimeInterval = 0.42

    /// 衝撃のクールダウン・アーム計算の基準（ウォームアップ終了時にセット）
    private var motionMonitorStartedUptime: TimeInterval = 0
    /// 起動直後のノイズで乾杯しないよう、この時刻までは加速度を無視する
    private var motionSamplesIgnoredUntilUptime: TimeInterval = 0
    private var didStartMotionArmingClock = false

    private let motionManager = CMMotionManager()
    private let motionDeliveryQueue = OperationQueue.main
    private var isDeviceMotionUpdatesRunning = false

    private let hapticsHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticsSoft = UIImpactFeedbackGenerator(style: .soft)
    private let hapticsLight = UIImpactFeedbackGenerator(style: .light)

    private var clinkPlayer: AVAudioPlayer?
    private var didConfigureAudioSession = false
    private var audioInterruptionObserver: NSObjectProtocol?

    private var lastImpactUptime: TimeInterval = 0

    /// ジョッキ：跳ね・スケール・傾き（過剰リアクション用）
    private(set) var mugOffsetY: CGFloat = 0
    private(set) var mugScale: CGFloat = 1
    private(set) var mugRotationDegrees: Double = 0

    /// Canvas 泡：同一フレームで birth・粒子・ID を揃える
    private(set) var foamBurstID = UUID()
    private(set) var foamBirthdate = Date()
    private(set) var foamBuds: [FoamBud] = []
    /// 次の乾杯用にバックグラウンドで用意した粒子（初回ラグ回避のため起動時に投入）
    private var foamBudPool: [FoamBud]?
    private var foamPoolRefillTask: Task<Void, Never>?

    /// 「CHEERS!!」オーバーレイ（連続乾杯では表示タイマーを張り替え）
    private(set) var cheersCaptionOpacity: Double = 0
    private var cheersCaptionHideTask: Task<Void, Never>?
    private let cheersCaptionHold: Duration = .milliseconds(620)
    private let cheersCaptionFade: TimeInterval = 0.26

    private(set) var isMotionAvailable = false

    private var fizzHapticTask: Task<Void, Never>?

    private static let remoteTriggerPath = "rooms/test_room/trigger"

    private var remoteTriggerRef: DatabaseReference?
    private var remoteTriggerHandle: DatabaseHandle?
    private var didPrimeRemoteTriggerListener = false
    private var lastRemoteTriggerSerialized: String?

    /// ローカル衝突からの `setValue` スパム防止（1〜2秒）
    private let remoteWriteCooldown: TimeInterval = 1.5
    private var lastRemoteWriteUptime: TimeInterval = 0
    /// 自分の `setValue` が `.observe` に返ってきたときだけ乾杯をスキップ（真偽フラグだと失敗時に永久スキップしうる）
    private var pendingEchoSerialized: String?

    init() {
        hapticsHeavy.prepare()
        hapticsSoft.prepare()
        hapticsLight.prepare()
        isMotionAvailable = motionManager.isDeviceMotionAvailable
        prepareClinkAudio()
    }

    private func resolveClinkAudioURL() -> URL? {
        let bundle = Bundle.main
        if let path = bundle.path(forResource: "clink", ofType: "mp3") {
            return URL(fileURLWithPath: path)
        }
        if let url = bundle.url(forResource: "clink", withExtension: "mp3") { return url }
        if let url = bundle.url(forResource: "clink", withExtension: "mp3", subdirectory: "beer_cheers") {
            return url
        }
        if let hits = bundle.urls(forResourcesWithExtension: "mp3", subdirectory: nil) {
            if let exact = hits.first(where: { $0.lastPathComponent.caseInsensitiveCompare("clink.mp3") == .orderedSame }) {
                return exact
            }
        }
        if let root = bundle.resourcePath {
            let fm = FileManager.default
            if let en = fm.enumerator(atPath: root) {
                for case let name as String in en {
                    guard name.lowercased().hasSuffix("clink.mp3") else { continue }
                    return URL(fileURLWithPath: (root as NSString).appendingPathComponent(name))
                }
            }
        }
        if let url = bundle.url(forResource: "clink", withExtension: "wav") { return url }
        return bundle.urls(forResourcesWithExtension: "wav", subdirectory: nil)?.first {
            $0.lastPathComponent.caseInsensitiveCompare("clink.wav") == .orderedSame
        }
    }

    private func prepareClinkAudio() {
        guard let url = resolveClinkAudioURL() else {
            clinkPlayer = nil
            return
        }
        let player: AVAudioPlayer?
        if let p = try? AVAudioPlayer(contentsOf: url) {
            player = p
        } else if let data = try? Data(contentsOf: url), let p = try? AVAudioPlayer(data: data) {
            player = p
        } else {
            player = nil
        }
        guard let resolved = player else {
            clinkPlayer = nil
            return
        }
        resolved.numberOfLoops = 0
        resolved.volume = 1.0
        resolved.prepareToPlay()
        clinkPlayer = resolved
    }

    private func ensureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            if !didConfigureAudioSession {
                try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                didConfigureAudioSession = true
            }
            try session.setActive(true, options: [])
        } catch {}
    }

    private func playClinkSound() {
        ensureAudioSession()
        if clinkPlayer == nil {
            prepareClinkAudio()
        }
        guard let player = clinkPlayer else { return }
        player.volume = 1.0
        player.currentTime = 0
        if !player.play() {
            prepareClinkAudio()
            clinkPlayer?.currentTime = 0
            clinkPlayer?.play()
        }
    }

    private func installAudioInterruptionObserver() {
        guard audioInterruptionObserver == nil else { return }
        let session = AVAudioSession.sharedInstance()
        audioInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let info = notification.userInfo,
                  let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue)
            else { return }
            let optionsValue = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            Task { @MainActor in
                self?.handleAudioSessionInterruption(type: type, options: options)
            }
        }
    }

    private func removeAudioInterruptionObserver() {
        if let token = audioInterruptionObserver {
            NotificationCenter.default.removeObserver(token)
            audioInterruptionObserver = nil
        }
    }

    private func handleAudioSessionInterruption(
        type: AVAudioSession.InterruptionType,
        options: AVAudioSession.InterruptionOptions
    ) {
        switch type {
        case .began:
            clinkPlayer?.pause()
        case .ended:
            if options.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true, options: [])
                prepareClinkAudio()
            }
        @unknown default:
            break
        }
    }

    /// 起動直後にバックグラウンドで生成した粒子を渡す（`AppEntryView` から）
    func seedFoamBudPool(_ buds: [FoamBud]) {
        if foamBudPool == nil {
            foamBudPool = buds
        }
    }

    func startMonitoring() {
        guard !isDeviceMotionUpdatesRunning else { return }
        installAudioInterruptionObserver()
        prepareClinkAudio()
        ensureAudioSession()
        guard motionManager.isDeviceMotionAvailable else { return }
        isDeviceMotionUpdatesRunning = true
        let now = ProcessInfo.processInfo.systemUptime
        motionSamplesIgnoredUntilUptime = now + 0.55
        didStartMotionArmingClock = false
        motionManager.deviceMotionUpdateInterval = 1.0 / 80.0
        hapticsHeavy.prepare()
        hapticsSoft.prepare()
        hapticsLight.prepare()
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: motionDeliveryQueue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let t = ProcessInfo.processInfo.systemUptime
            guard t >= self.motionSamplesIgnoredUntilUptime else { return }
            if !self.didStartMotionArmingClock {
                self.didStartMotionArmingClock = true
                self.motionMonitorStartedUptime = t
            }
            let ua = motion.userAcceleration
            let magnitude = sqrt(ua.x * ua.x + ua.y * ua.y + ua.z * ua.z)
            guard magnitude >= self.currentImpactThresholdG() else { return }
            self.evaluateImpact()
        }
    }

    private func currentImpactThresholdG() -> Double {
        let elapsed = ProcessInfo.processInfo.systemUptime - motionMonitorStartedUptime
        return elapsed <= motionArmingDuration ? impactThresholdArmingG : impactThresholdG
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isDeviceMotionUpdatesRunning = false
        didStartMotionArmingClock = false
        removeAudioInterruptionObserver()
        foamPoolRefillTask?.cancel()
        foamPoolRefillTask = nil
        fizzHapticTask?.cancel()
        fizzHapticTask = nil
        cheersCaptionHideTask?.cancel()
        cheersCaptionHideTask = nil
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            cheersCaptionOpacity = 0
        }
    }

    /// `rooms/test_room/trigger` の変更で乾杯演出を発火（初回はベースライン確定のみ）
    func startRemoteTriggerListening() {
        stopRemoteTriggerListening()
        guard FirebaseApp.app() != nil else {
            #if DEBUG
            print("[AirCheers] FirebaseApp が nil のため Realtime DB を監視しません（GoogleService-Info 等を確認）")
            #endif
            return
        }
        let ref = Database.database().reference(withPath: Self.remoteTriggerPath)
        ref.keepSynced(true)
        remoteTriggerRef = ref
        remoteTriggerHandle = ref.observe(.value) { [weak self] snapshot in
            let exists = snapshot.exists()
            let serialized = Self.serializeRemoteTriggerValue(snapshot.value)
            Task { @MainActor [weak self] in
                self?.processRemoteTriggerUpdate(exists: exists, serialized: serialized)
            }
        }
    }

    func stopRemoteTriggerListening() {
        if let ref = remoteTriggerRef, let handle = remoteTriggerHandle {
            ref.removeObserver(withHandle: handle)
        }
        remoteTriggerHandle = nil
        remoteTriggerRef = nil
        didPrimeRemoteTriggerListener = false
        lastRemoteTriggerSerialized = nil
        pendingEchoSerialized = nil
    }

    private nonisolated static func serializeRemoteTriggerValue(_ value: Any?) -> String {
        switch value {
        case nil:
            return "__nil__"
        case is NSNull:
            return "__nsnull__"
        case let n as NSNumber:
            return "num:\(n)"
        case let s as String:
            return "str:\(s)"
        case let b as Bool:
            return "bool:\(b)"
        case let i as Int:
            return "int:\(i)"
        case let i64 as Int64:
            return "i64:\(i64)"
        case let d as Double:
            return "double:\(d)"
        case let dict as [String: Any]:
            return jsonSerializedString(dict: dict) ?? "dict:\(dict)"
        case let nsDict as NSDictionary:
            if let dict = nsDict as? [String: Any] {
                return jsonSerializedString(dict: dict) ?? "nsdict:\(nsDict)"
            }
            return "nsdict:\(nsDict)"
        default:
            return "any:\(String(describing: value))"
        }
    }

    private nonisolated static func jsonSerializedString(dict: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8)
        else { return nil }
        return "json:\(s)"
    }

    private func processRemoteTriggerUpdate(exists: Bool, serialized: String) {
        if !didPrimeRemoteTriggerListener {
            didPrimeRemoteTriggerListener = true
            lastRemoteTriggerSerialized = serialized
            return
        }
        guard serialized != lastRemoteTriggerSerialized else { return }
        lastRemoteTriggerSerialized = serialized

        if let pending = pendingEchoSerialized {
            if pending == serialized {
                pendingEchoSerialized = nil
                return
            }
            pendingEchoSerialized = nil
        }

        guard exists else { return }
        triggerCheers()
    }

    private func evaluateImpact() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastImpactUptime >= impactCooldown else { return }
        lastImpactUptime = now
        triggerCheers()
        publishCheersTriggerToRemoteIfNeeded()
    }

    /// 衝撃検知時に `trigger` を更新（他人端末の乾杯にも繋がる）。書き込みはスロットリングする。
    private func publishCheersTriggerToRemoteIfNeeded() {
        guard FirebaseApp.app() != nil else {
            #if DEBUG
            print("[AirCheers] FirebaseApp が nil のため trigger へ書き込みません")
            #endif
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastRemoteWriteUptime >= remoteWriteCooldown else { return }
        lastRemoteWriteUptime = now

        let ref = Database.database().reference(withPath: Self.remoteTriggerPath)
        let payload: [String: Any] = [
            "ts": Date().timeIntervalSince1970,
            "id": UUID().uuidString,
        ]

        let outgoingSerialized = Self.serializeRemoteTriggerValue(payload)
        pendingEchoSerialized = outgoingSerialized

        ref.setValue(payload) { [weak self] error, _ in
            Task { @MainActor in
                if let error {
                    self?.pendingEchoSerialized = nil
                    #if DEBUG
                    print("[AirCheers] setValue 失敗: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    private func playFizzHaptics() {
        fizzHapticTask?.cancel()
        hapticsSoft.prepare()
        hapticsLight.prepare()
        fizzHapticTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(95))
            for i in 0..<8 {
                guard !Task.isCancelled else { return }
                if i.isMultiple(of: 2) {
                    hapticsSoft.impactOccurred(intensity: Double.random(in: 0.38...0.72))
                } else {
                    hapticsLight.impactOccurred(intensity: Double.random(in: 0.32...0.58))
                }
                try? await Task.sleep(for: .milliseconds(52 + i * 6))
            }
        }
    }

    private func consumeFoamBudsForBurst() -> [FoamBud] {
        let pack: [FoamBud]
        if let pooled = foamBudPool {
            foamBudPool = nil
            pack = pooled
        } else {
            pack = BeerFoamBudFactory.makeBuds()
        }
        scheduleFoamBudPoolRefill()
        return pack
    }

    private func scheduleFoamBudPoolRefill() {
        foamPoolRefillTask?.cancel()
        foamPoolRefillTask = Task { @MainActor in
            let next = await Task.detached { BeerFoamBudFactory.makeBuds() }.value
            guard !Task.isCancelled else { return }
            if foamBudPool == nil {
                foamBudPool = next
            }
        }
    }

    private func flashCheersCaption() {
        cheersCaptionHideTask?.cancel()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            cheersCaptionOpacity = 1
        }
        cheersCaptionHideTask = Task { @MainActor in
            try? await Task.sleep(for: self.cheersCaptionHold)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: self.cheersCaptionFade)) {
                self.cheersCaptionOpacity = 0
            }
        }
    }

    private func triggerCheers() {
        foamBuds = consumeFoamBudsForBurst()
        foamBurstID = UUID()
        foamBirthdate = Date()
        flashCheersCaption()

        hapticsHeavy.prepare()
        hapticsHeavy.impactOccurred(intensity: 1.0)
        playFizzHaptics()

        let kickTilt = Double.random(in: 26...38) * (Bool.random() ? 1 : -1)
        let midTilt = -kickTilt * 0.45

        withAnimation(.interpolatingSpring(stiffness: 420, damping: 14)) {
            mugOffsetY = -118
            mugScale = 1.22
            mugRotationDegrees = kickTilt
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(.interpolatingSpring(stiffness: 280, damping: 13)) {
                self.mugOffsetY = 28
                self.mugScale = 0.94
                self.mugRotationDegrees = midTilt
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.interpolatingSpring(stiffness: 210, damping: 17)) {
                self.mugOffsetY = -10
                self.mugScale = 1.05
                self.mugRotationDegrees = kickTilt * 0.35
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 22)) {
                self.mugOffsetY = 0
                self.mugScale = 1
                self.mugRotationDegrees = 0
            }
        }

        // 泡・ジョッキの Observable 更新を先にコミットしてから音を鳴らし、初回だけ音先行になりがちなズレを減らす
        DispatchQueue.main.async {
            self.playClinkSound()
        }
    }
}
