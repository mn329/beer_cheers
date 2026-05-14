//
//  CheersRemoteSync.swift
//  beer_cheers
//
//  Realtime Database の `rooms/<roomID>/trigger` を介して
//  他端末との「乾杯」イベントを同期するサービス。
//
//  ・観測：trigger が変化したら `onRemoteCheers` を呼ぶ。初回はベースライン確定のみ。
//  ・送信：ローカル衝撃時に trigger を更新し、自分の書き込みエコーは抑制する。
//  ・部屋切替：start 時に roomID を渡す（アカウント画面からの切替を想定）。
//  ・同一判定は JSON 文字列ではなく id + 正規化 ts（コンソールの Int/Double 差・丸めに強い）。
//

import FirebaseDatabase
import Foundation

@MainActor
final class CheersRemoteSync {
    /// 既定の部屋 ID（アカウント画面実装前の互換用）
    static let defaultRoomID = "test_room"

    /// ローカル衝突からの `setValue` スパム防止クールダウン（秒）
    private let writeCooldown: TimeInterval = 1.5

    private(set) var currentRoomID: String?

    private var triggerRef: DatabaseReference?
    private var triggerHandle: DatabaseHandle?
    private var didPrimeListener = false
    /// 直近スナップショットの同一判定用（`triggerSignature` 優先、取れなければ `serialize`）
    private var lastSignature: String?

    private var lastWriteUptime: TimeInterval = 0
    /// 自分の `setValue` の戻りを `.observe` で無視するためのトークン
    private var pendingEchoSignature: String?

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
                self?.processUpdate(exists: exists, value: value, serialized: serialized)
            }
        }
    }

    func stopListening() {
        if let ref = triggerRef, let handle = triggerHandle {
            ref.removeObserver(withHandle: handle)
        }
        triggerHandle = nil
        triggerRef = nil
        didPrimeListener = false
        lastSignature = nil
        pendingEchoSignature = nil
        onRemoteCheers = nil
    }

    /// ローカル衝撃時に呼ぶ。クールダウンと自分エコー抑制込み。
    func publishLocalCheers() {
        guard FirebaseBootstrap.isConfigured else {
            #if DEBUG
                print(
                    "[AirCheers] Firebase 未初期化のため trigger へ書き込みません。起動ログの [beer_cheers] を確認し、バンドルに GoogleService-Info.plist または Firebase Project Settings - beercheers.plist を置いてください（README 参照）。"
                )
            #endif
            return
        }
        guard let roomID = currentRoomID else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastWriteUptime >= writeCooldown else { return }
        lastWriteUptime = now

        let payload: [String: Any] = [
            "ts": Date().timeIntervalSince1970,
            "id": UUID().uuidString,
        ]
        pendingEchoSignature = Self.triggerSignature(from: payload) ?? Self.serialize(payload)

        let ref = Database.database().reference(withPath: Self.triggerPath(for: roomID))
        ref.setValue(payload) { [weak self] error, _ in
            Task { @MainActor in
                if let error {
                    self?.pendingEchoSignature = nil
                    #if DEBUG
                        print("[AirCheers] setValue 失敗: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    // MARK: - Internal

    private func processUpdate(exists: Bool, value: Any?, serialized: String) {
        let signature = Self.updateSignature(exists: exists, value: value, serialized: serialized)
        if !didPrimeListener {
            didPrimeListener = true
            lastSignature = signature
            return
        }
        guard signature != lastSignature else { return }
        lastSignature = signature

        if let pending = pendingEchoSignature {
            if pending == signature {
                pendingEchoSignature = nil
                return
            }
            pendingEchoSignature = nil
        }

        guard exists else { return }
        onRemoteCheers?()
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
