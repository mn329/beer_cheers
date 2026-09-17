//
//  AirCheersViewModel.swift
//  beer_cheers
//
//  乾杯画面のオーケストレーター。
//  Service 層（Motion / Audio / Haptics / Remote / Effects）を束ね、
//  画面が必要とする状態だけを露出する。
//

import Observation
import SwiftUI

@MainActor
@Observable
final class AirCheersViewModel {
    // MARK: - Public state (View からの観測対象)

    /// 視覚演出（ジョッキ・泡・キャプション）
    let effects: CheersEffectsController

    /// 端末で Device Motion が使えるか
    private(set) var isMotionAvailable: Bool

    /// 現在接続中のルーム ID（アカウント画面で切替可能）
    private(set) var roomID: String

    /// リモート未達時のユーザー向けメッセージ（共通バナー用）。自動クリアされる。
    private(set) var remoteSyncErrorMessage: String?

    // MARK: - Services

    private let motionDetector: MotionImpactDetector
    private let audio: ClinkAudioPlayer
    private let haptics: CheersHapticsPlayer
    private let remote: CheersRemoteSync

    /// バナー自動クリアの世代。古い Task が新しいエラーを消さないようにする。
    private var remoteErrorClearGeneration = 0

    // MARK: - Init

    init(
        motionDetector: MotionImpactDetector = .init(),
        audio: ClinkAudioPlayer = .init(),
        haptics: CheersHapticsPlayer = .init(),
        remote: CheersRemoteSync = .init(),
        effects: CheersEffectsController = .init(),
        roomID: String = CheersRemoteSync.defaultRoomID
    ) {
        self.motionDetector = motionDetector
        self.audio = audio
        self.haptics = haptics
        self.remote = remote
        self.effects = effects
        self.roomID = roomID
        self.isMotionAvailable = motionDetector.isAvailable
    }

    // MARK: - Lifecycle

    /// 起動直後にバックグラウンドで生成した粒子を渡す（`AppEntryView` から）
    func seedFoamBudPool(_ buds: [FoamBud]) {
        effects.seedFoamBudPool(buds)
    }

    func startMonitoring() {
        audio.activate()
        haptics.prepare()
        startWatchConnectivity()
        motionDetector.start { [weak self] in
            self?.handleLocalImpact()
        }
    }

    func stopMonitoring() {
        motionDetector.stop()
        audio.deactivate()
        haptics.cancelOngoing()
        effects.reset()
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
        let wasListening = remote.isListening
        if wasListening {
            stopRemoteTriggerListening()
        }
        roomID = trimmed
        if wasListening {
            startRemoteTriggerListening()
        }
    }

    // MARK: - Impact handling

    private func startWatchConnectivity() {
        CheersPhoneConnectivity.shared.onCheersFromWatch = { [weak self] in
            self?.handleWatchCheers()
        }
        CheersPhoneConnectivity.shared.activate()
    }

    /// ローカル演出を先に出し、その後リモートへ同期する（失敗しても演出は消さない）。
    private func handleLocalImpact() {
        triggerCheers()
        publishRemoteCheers()
    }

    /// Watch からの乾杯。演出 + 同一ルームへのリモート同期。
    private func handleWatchCheers() {
        triggerCheers()
        publishRemoteCheers()
    }

    private func publishRemoteCheers() {
        if let immediateFailure = remote.publishLocalCheers(onFailure: { [weak self] failure in
            self?.presentRemoteSyncFailure(failure)
        }) {
            // 監視開始前の一瞬の notInRoom はユーザー向けに出さない（ローカル演出は済んでいる）
            if case .notInRoom = immediateFailure, !remote.isListening {
                #if DEBUG
                    print("[AirCheers] 監視未開始のため notInRoom バナーを抑制")
                #endif
                return
            }
            presentRemoteSyncFailure(immediateFailure)
        }
    }

    private func presentRemoteSyncFailure(_ failure: CheersRemotePublishFailure) {
        remoteSyncErrorMessage = failure.userMessage
        remoteErrorClearGeneration &+= 1
        let generation = remoteErrorClearGeneration
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, self.remoteErrorClearGeneration == generation else { return }
            self.remoteSyncErrorMessage = nil
        }
    }

    private func triggerCheers() {
        effects.playBurst()
        haptics.playImpact()

        // 泡・ジョッキの Observable 更新を先にコミットしてから音を鳴らし、初回だけ音先行になりがちなズレを減らす
        DispatchQueue.main.async {
            self.audio.play()
        }
    }
}
