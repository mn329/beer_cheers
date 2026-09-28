//
//  RealtimeDatabaseClient.swift
//  beer_cheers
//
//  Realtime Database の共通 async ヘルパー（Repository から利用）。
//

import FirebaseDatabase
import Foundation

enum RealtimeDatabaseClient {
    /// 単発の value 取得。`timeout` 指定時は時間切れで `timeoutError` を投げる。
    static func getSnapshot(
        _ ref: DatabaseReference,
        timeout: Duration? = nil,
        timeoutError: Error? = nil
    ) async throws -> DataSnapshot {
        Database.database().goOnline()

        return try await withCheckedThrowingContinuation { continuation in
            final class Once: @unchecked Sendable {
                private let lock = NSLock()
                private var finished = false

                func resume(_ body: () -> Void) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !finished else { return }
                    finished = true
                    body()
                }
            }

            let once = Once()
            ref.observeSingleEvent(
                of: .value,
                with: { snapshot in
                    once.resume {
                        continuation.resume(returning: snapshot)
                    }
                },
                withCancel: { error in
                    once.resume {
                        continuation.resume(throwing: error)
                    }
                }
            )

            if let timeout, let timeoutError {
                Task {
                    try? await Task.sleep(for: timeout)
                    once.resume {
                        continuation.resume(throwing: timeoutError)
                    }
                }
            }
        }
    }

    static func setValue(_ ref: DatabaseReference, _ value: Any) async throws {
        Database.database().goOnline()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setValue(value) { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// トランザクションで書き換える。確定したら確定後の値、`update` が abort したら nil を返す。
    /// `update` はサーバー値との競合のたびに Firebase のスレッドで何度も呼ばれるため、副作用を持たせない。
    static func runTransaction(
        _ ref: DatabaseReference,
        update: @escaping @Sendable (MutableData) -> TransactionResult
    ) async throws -> DataSnapshot? {
        Database.database().goOnline()
        return try await withCheckedThrowingContinuation { continuation in
            ref.runTransactionBlock(update) { error, committed, snapshot in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: committed ? snapshot : nil)
                }
            }
        }
    }

    /// 接続が切れたときにサーバー側で削除する（アプリ強制終了・圏外でも残らないように）。
    static func removeOnDisconnect(_ ref: DatabaseReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.onDisconnectRemoveValue { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// 予約済みの切断時操作を取り消す（自分で退出したあとに誤って消さないように）。
    static func cancelDisconnectOperations(_ ref: DatabaseReference) {
        ref.cancelDisconnectOperations()
    }

    /// サーバーとの接続状態（`.info/connected`）を監視する。戻り値のクロージャで停止する。
    static func observeConnection(onChange: @escaping @MainActor (Bool) -> Void) -> () -> Void {
        let ref = Database.database().reference(withPath: ".info/connected")
        let handle = ref.observe(.value) { snapshot in
            let isConnected = snapshot.value as? Bool ?? false
            Task { @MainActor in
                onChange(isConnected)
            }
        }
        return {
            ref.removeObserver(withHandle: handle)
        }
    }

    static func removeValue(_ ref: DatabaseReference) async throws {
        Database.database().goOnline()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.removeValue { error, _ in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
