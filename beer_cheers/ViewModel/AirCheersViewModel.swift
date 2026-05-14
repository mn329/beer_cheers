//
//  AirCheersViewModel.swift
//  beer_cheers
//
//  乾杯画面のオーケストレーター。
//  Service 層（MotionImpactDetector / ClinkAudioPlayer / CheersHapticsPlayer / CheersRemoteSync）を
//  束ねて、画面が必要とする状態（ジョッキ・泡・キャプション）だけを露出する。
//

import Observation
import SwiftUI

@MainActor
@Observable
final class AirCheersViewModel {
    // MARK: - Public state (View からの観測対象)

    /// ジョッキ：跳ね・スケール・傾き（過剰リアクション用）
    private(set) var mugOffsetY: CGFloat = 0
    private(set) var mugScale: CGFloat = 1
    private(set) var mugRotationDegrees: Double = 0

    /// Canvas 泡：同一フレームで birth・粒子・ID を揃える
    private(set) var foamBurstID = UUID()
    private(set) var foamBirthdate = Date()
    private(set) var foamBuds: [FoamBud] = []

    /// 「CHEERS!!」オーバーレイ（連続乾杯では表示タイマーを張り替え）
    private(set) var cheersCaptionOpacity: Double = 0

    /// 端末で Device Motion が使えるか
    private(set) var isMotionAvailable: Bool

    /// 現在接続中のルーム ID（アカウント画面で切替可能）
    private(set) var roomID: String

    // MARK: - Services

    private let motionDetector: MotionImpactDetector
    private let audio: ClinkAudioPlayer
    private let haptics: CheersHapticsPlayer
    private let remote: CheersRemoteSync

    // MARK: - Animation / caption timing

    private let cheersCaptionHold: Duration = .milliseconds(620)
    private let cheersCaptionFade: TimeInterval = 0.26
    private var cheersCaptionHideTask: Task<Void, Never>?

    // MARK: - Foam pool

    /// 次の乾杯用にバックグラウンドで用意した粒子（初回ラグ回避のため起動時に投入）
    private var foamBudPool: [FoamBud]?
    private var foamPoolRefillTask: Task<Void, Never>?

    // MARK: - Init

    init(
        motionDetector: MotionImpactDetector = .init(),
        audio: ClinkAudioPlayer = .init(),
        haptics: CheersHapticsPlayer = .init(),
        remote: CheersRemoteSync = .init(),
        roomID: String = CheersRemoteSync.defaultRoomID
    ) {
        self.motionDetector = motionDetector
        self.audio = audio
        self.haptics = haptics
        self.remote = remote
        self.roomID = roomID
        self.isMotionAvailable = motionDetector.isAvailable
    }

    // MARK: - Lifecycle

    /// 起動直後にバックグラウンドで生成した粒子を渡す（`AppEntryView` から）
    func seedFoamBudPool(_ buds: [FoamBud]) {
        if foamBudPool == nil {
            foamBudPool = buds
        }
    }

    func startMonitoring() {
        audio.activate()
        haptics.prepare()
        motionDetector.start { [weak self] in
            self?.handleLocalImpact()
        }
    }

    func stopMonitoring() {
        motionDetector.stop()
        audio.deactivate()
        haptics.cancelOngoing()
        foamPoolRefillTask?.cancel()
        foamPoolRefillTask = nil
        cheersCaptionHideTask?.cancel()
        cheersCaptionHideTask = nil
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            cheersCaptionOpacity = 0
        }
    }

    func startRemoteTriggerListening() {
        remote.startListening(roomID: roomID) { [weak self] in
            self?.triggerCheers()
        }
    }

    func stopRemoteTriggerListening() {
        remote.stopListening()
    }

    /// アカウント画面からの部屋切替。監視中なら一旦停止→新しい部屋で再開する。
    func switchRoom(to newRoomID: String) {
        let trimmed = newRoomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != roomID else { return }
        let wasListening = remote.currentRoomID != nil
        if wasListening {
            stopRemoteTriggerListening()
        }
        roomID = trimmed
        if wasListening {
            startRemoteTriggerListening()
        }
    }

    // MARK: - Impact handling

    private func handleLocalImpact() {
        triggerCheers()
        remote.publishLocalCheers()
    }

    private func triggerCheers() {
        foamBuds = consumeFoamBudsForBurst()
        foamBurstID = UUID()
        foamBirthdate = Date()
        flashCheersCaption()

        haptics.playImpact()
        animateMugReaction()

        // 泡・ジョッキの Observable 更新を先にコミットしてから音を鳴らし、初回だけ音先行になりがちなズレを減らす
        DispatchQueue.main.async {
            self.audio.play()
        }
    }

    // MARK: - Mug animation

    private func animateMugReaction() {
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
    }

    // MARK: - Caption

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

    // MARK: - Foam pool

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
}
