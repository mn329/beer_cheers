//
//  CheersRemoteSync.swift
//  beer_cheers
//
//  Realtime Database の `rooms/<roomID>/trigger` を介して
//  他端末との「乾杯」イベントを同期するサービス。
//
//  ・観測：trigger が変化したら `onRemoteCheers` を呼ぶ。初回はベースライン確定のみ。
//  ・送信：ローカル衝撃時に trigger を更新し、自分の書き込みエコーは抑制する。
//  ・部屋切替：start 時に roomID を渡す。世代トークンで旧 observe の遅延 Task を無視する。
//  ・同一判定は JSON 文字列ではなく id + 正規化 ts（コンソールの Int/Double 差・丸めに強い）。
//

import FirebaseDatabase
import Foundation

/// `publishLocalCheers` が書き込みを試みた結果のうち、ユーザー向け未達表示の対象。
enum CheersRemotePublishFailure: Equatable {
    case firebaseNotConfigured
    case notInRoom
    case writeFailed(String)

    var userMessage: String {
        switch self {
        case .firebaseNotConfigured, .notInRoom, .writeFailed:
            return "相手への同期に失敗しました"
        }
    }
}

@MainActor
final class CheersRemoteSync {
    /// 互換用の旧既定名。新規起動では使わず、ゲスト用ランダム ID を割り当てる。
    static let defaultRoomID = "test_room"

    /// ローカル衝突からの `setValue` スパム防止クールダウン（秒）
    private let writeCooldown: TimeInterval = 1.5

    /// 自分エコー待ちの上限。取りこぼしで永久抑制しないためのタイムアウト（秒）
    private let pendingEchoTimeout: TimeInterval = 3.0

    private(set) var currentRoomID: String?

    /// 監視ハンドルがあるとき true（部屋切替の再開判定用）
    var isListening: Bool { triggerHandle != nil }

    private var triggerRef: DatabaseReference?
    private var triggerHandle: DatabaseHandle?
    private var didPrimeListener = false
    /// 直近スナップショットの同一判定用（`triggerSignature` 優先、取れなければ `serialize`）
    private var lastSignature: String?

    private var lastWriteUptime: TimeInterval = 0
    /// 自分の `setValue` の戻りを `.observe` で無視するためのトークン
    private var pendingEchoSignature: String?
    private var pendingEchoExpireTask: Task<Void, Never>?

    /// `startListening` / `stopListening` ごとに増やす。遅延した observe Task を捨てる。
    private var listenGeneration = 0

    private var onRemoteCheers: (@MainActor () -> Void)?

    /// 指定の room の trigger を監視し始める。初回は値が来てもベースライン確定のみ（既存値で乾杯しない）。
    func startListening(roomID: String, onRemoteCheers: @escaping @MainActor () -> Void) {
        stopListening()
        guard FirebaseBootstrap.isConfigured else {
            #if DEBUG
                print(
                    "[AirCheers] Firebase 未初期化のため Realtime DB を監視しません。起動ログの [beer_cheers] を確認し、バンドルに GoogleService-Info.plist または Firebase Project Settings - beercheers.plist を置いてください（README 参照）。"
                )
            #endif
            return
        }
        listenGeneration &+= 1
        let generation = listenGeneration
        self.onRemoteCheers = onRemoteCheers
        currentRoomID = roomID
        let ref = Database.database().reference(withPath: Self.triggerPath(for: roomID))
        ref.keepSynced(true)
        triggerRef = ref
        triggerHandle = ref.observe(.value) { [weak self] snapshot in
            let exists = snapshot.exists()
            let value = snapshot.value
            let serialized = Self.serialize(value)
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.listenGeneration == generation else {
                    #if DEBUG
                        print("[AirCheers] 古い世代の trigger 更新を無視 generation=\(generation) current=\(self.listenGeneration)")
                    #endif
                    return
                }
                self.processUpdate(exists: exists, value: value, serialized: serialized)
            }
        }
        #if DEBUG
            print("[AirCheers] trigger 監視開始 room=\(roomID) generation=\(generation)")
        #endif
    }

    func stopListening() {
        listenGeneration &+= 1
        if let ref = triggerRef, let handle = triggerHandle {
            ref.removeObserver(withHandle: handle)
            ref.keepSynced(false)
        }
        triggerHandle = nil
        triggerRef = nil
        currentRoomID = nil
        didPrimeListener = false
        lastSignature = nil
        clearPendingEcho()
        onRemoteCheers = nil
    }

    /// ローカル衝撃時に呼ぶ。クールダウンと自分エコー抑制込み。
    /// - Returns: 書き込みを試みた結果。クールダウンスキップは `nil`（未達エラーにしない）。
    ///   非同期の `setValue` 失敗は `onFailure` で返す。
    @discardableResult
    func publishLocalCheers(onFailure: (@MainActor (CheersRemotePublishFailure) -> Void)? = nil) -> CheersRemotePublishFailure? {
        guard FirebaseBootstrap.isConfigured else {
            #if DEBUG
                print(
                    "[AirCheers] Firebase 未初期化のため trigger へ書き込みません。起動ログの [beer_cheers] を確認し、バンドルに GoogleService-Info.plist または Firebase Project Settings - beercheers.plist を置いてください（README 参照）。"
                )
            #endif
            return .firebaseNotConfigured
        }
        guard let roomID = currentRoomID else {
            #if DEBUG
                print("[AirCheers] currentRoomID が nil のため trigger へ書き込みません")
            #endif
            return .notInRoom
        }
        // ゲスト専用ルームは端末ローカルのみ。RTDB に trigger を残さない。
        if roomID.hasPrefix("guest_") {
            #if DEBUG
                print("[AirCheers] ゲストルームのため remote publish をスキップ")
            #endif
            return nil
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastWriteUptime >= writeCooldown else {
            #if DEBUG
                print("[AirCheers] writeCooldown のため setValue をスキップ")
            #endif
            return nil
        }
        lastWriteUptime = now

        let payload: [String: Any] = [
            "ts": Date().timeIntervalSince1970,
            "id": UUID().uuidString,
        ]
        let signature = Self.triggerSignature(from: payload) ?? Self.serialize(payload)
        armPendingEcho(signature: signature)

        let publishStartedAt = Date()
        let ref = Database.database().reference(withPath: Self.triggerPath(for: roomID))
        ref.setValue(payload) { [weak self] error, _ in
            Task { @MainActor in
                if let error {
                    self?.clearPendingEcho()
                    #if DEBUG
                        print("[AirCheers] setValue 失敗: \(error.localizedDescription)")
                    #endif
                    onFailure?(.writeFailed(error.localizedDescription))
                } else {
                    #if DEBUG
                        let ms = Int(Date().timeIntervalSince(publishStartedAt) * 1000)
                        print("[AirCheers] setValue 成功 room=\(roomID) elapsedMs=\(ms) sig=\(signature)")
                    #endif
                }
            }
        }
        return nil
    }

    // MARK: - Internal

    private func processUpdate(exists: Bool, value: Any?, serialized: String) {
        let signature = Self.updateSignature(exists: exists, value: value, serialized: serialized)
        if !didPrimeListener {
            didPrimeListener = true
            lastSignature = signature
            #if DEBUG
                print("[AirCheers] trigger ベースライン確定 sig=\(signature)")
            #endif
            return
        }
        guard signature != lastSignature else { return }
        lastSignature = signature

        // 自分エコー: 一致するまで pending を保持（途中の他端末更新では捨てない）
        if let pending = pendingEchoSignature, pending == signature {
            clearPendingEcho()
            #if DEBUG
                print("[AirCheers] 自分エコー抑制 sig=\(signature)")
            #endif
            return
        }

        guard exists else { return }
        #if DEBUG
            print("[AirCheers] リモート乾杯受信 sig=\(signature)")
        #endif
        onRemoteCheers?()
    }

    private func armPendingEcho(signature: String) {
        clearPendingEcho()
        pendingEchoSignature = signature
        let timeout = pendingEchoTimeout
        pendingEchoExpireTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(timeout))
            guard !Task.isCancelled else { return }
            guard let self, self.pendingEchoSignature == signature else { return }
            #if DEBUG
                print("[AirCheers] pendingEcho タイムアウト sig=\(signature)")
            #endif
            self.pendingEchoSignature = nil
            self.pendingEchoExpireTask = nil
        }
    }

    private func clearPendingEcho() {
        pendingEchoExpireTask?.cancel()
        pendingEchoExpireTask = nil
        pendingEchoSignature = nil
    }

    private static func triggerPath(for roomID: String) -> String { "rooms/\(roomID)/trigger" }

    /// `id` と `ts` が取れるときだけ安定キーを返す（コンソール編集や NSNumber 経由でも比較がぶれにくい）
    private nonisolated static func triggerSignature(from value: Any?) -> String? {
        let dict: [String: Any]?
        switch value {
        case let d as [String: Any]:
            dict = d
        case let ns as NSDictionary:
            dict = ns as? [String: Any]
        default:
            dict = nil
        }
        guard let dict else { return nil }
        let id = dict["id"] as? String ?? ""
        guard !id.isEmpty else { return nil }
        let ts = normalizedTimestamp(dict["ts"])
        guard ts.isFinite else { return nil }
        return "id:\(id)|ts:\(ts)"
    }

    private nonisolated static func normalizedTimestamp(_ v: Any?) -> Double {
        switch v {
        case let d as Double:
            return d
        case let f as Float:
            return Double(f)
        case let i as Int:
            return Double(i)
        case let i64 as Int64:
            return Double(i64)
        case let n as NSNumber:
            return n.doubleValue
        default:
            return .nan
        }
    }

    private nonisolated static func updateSignature(exists: Bool, value: Any?, serialized: String) -> String {
        guard exists else { return "__absent__" }
        return triggerSignature(from: value) ?? serialized
    }

    private nonisolated static func serialize(_ value: Any?) -> String {
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
            return jsonString(dict: dict) ?? "dict:\(dict)"
        case let nsDict as NSDictionary:
            if let dict = nsDict as? [String: Any] {
                return jsonString(dict: dict) ?? "nsdict:\(nsDict)"
            }
            return "nsdict:\(nsDict)"
        default:
            return "any:\(String(describing: value))"
        }
    }

    private nonisolated static func jsonString(dict: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let s = String(data: data, encoding: .utf8)
        else { return nil }
        return "json:\(s)"
    }
}
