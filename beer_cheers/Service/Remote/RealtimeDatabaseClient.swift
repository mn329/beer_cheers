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
