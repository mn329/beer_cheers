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

    /// この端末（または Watch）で起きた乾杯の回数。リモート受信分は含めない。
    private(set) var localCheersCount = 0

    /// ルーム参加中にチュートリアルを見返したとき、練習の乾杯が仲間へ届かないよう送信を止める。
    var isPracticeMode = false

    /// 直近の乾杯を送ってきた相手のメンバー ID。自分の乾杯や送り主を載せない旧バージョンからの乾杯では nil。
    private(set) var lastCheersSenderID: String?

    // MARK: - Services

    private let motionDetector: MotionImpactDetector
    private let audio: ClinkAudioPlayer
    private let haptics: CheersHapticsPlayer
    private let remote: CheersRemoteSync
    private let memberID: String
    /// 画面側が監視を望んでいるか。ゲストルーム中は要求があっても実際には監視しない。
    private var isRemoteListeningRequested = false

    // MARK: - Init

    init(
        motionDetector: MotionImpactDetector = .init(),
        audio: ClinkAudioPlayer = .init(),
        haptics: CheersHapticsPlayer = .init(),
        remote: CheersRemoteSync = .init(),
        effects: CheersEffectsController = .init(),
        roomID: String = RoomSessionStore.loadCurrentRoomID(),
        memberID: String = RoomSessionStore.stableMemberID()
    ) {
        self.motionDetector = motionDetector
        self.audio = audio
        self.haptics = haptics
        self.remote = remote
        self.effects = effects
        self.roomID = roomID
        self.memberID = memberID
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
        ensureWatchConnectivity()
        motionDetector.start { [weak self] in
            self?.handleLocalImpact()
        }
    }

    func stopMonitoring() {
        // Watch 連携はタブを離れても維持する（ルーム画面中の Watch 乾杯のため）
        motionDetector.stop()
        audio.deactivate()
        haptics.cancelOngoing()
        effects.reset()
    }

    /// アプリ起動〜本体表示で一度呼べばよい。stopMonitoring では切らない。
    func ensureWatchConnectivity() {
        CheersPhoneConnectivity.shared.onCheersFromWatch = { [weak self] in
            self?.handleWatchCheers()
        }
        CheersPhoneConnectivity.shared.activate()
    }

    func startRemoteTriggerListening() {
        isRemoteListeningRequested = true
        applyRemoteListening()
    }

    func stopRemoteTriggerListening() {
        isRemoteListeningRequested = false
        remote.stopListening()
    }

    /// アカウント画面からの部屋切替。監視を要求されていれば新しい部屋で張り直す。
    func switchRoom(to newRoomID: String) {
        let trimmed = newRoomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != roomID else { return }
        remote.stopListening()
        roomID = trimmed
        applyRemoteListening()
    }

    /// ゲストルームは自分しかいないため、監視も送信もしない（Realtime Database の無駄な読み書きを避ける）。
    /// 送信は `CheersRemoteSync.publishLocalCheers` が監視中のルームにだけ行うので、監視を止めれば送信も止まる。
    private func applyRemoteListening() {
        guard isRemoteListeningRequested, !RoomSessionStore.isGuestRoomID(roomID) else { return }
        remote.startListening(roomID: roomID) { [weak self] senderID in
            self?.lastCheersSenderID = senderID
            self?.triggerCheers()
        }
    }

    // MARK: - Impact handling

    private func handleLocalImpact() {
        playCheersLocallyAndPublish()
    }

    /// Watch からの乾杯。演出 + 同一ルームへのリモート同期。
    private func handleWatchCheers() {
        playCheersLocallyAndPublish()
    }

    private func playCheersLocallyAndPublish() {
        lastCheersSenderID = nil
        triggerCheers()
        localCheersCount += 1
        guard !isPracticeMode else { return }
        remote.publishLocalCheers(senderID: memberID)
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
