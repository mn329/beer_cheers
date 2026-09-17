//
//  RoomService.swift
//  beer_cheers
//
//  Realtime Database の `rooms/{roomID}/meta`・`members` を扱う（製品 MVP）。
//

import FirebaseDatabase
import Foundation

enum RoomService {
    /// ルーム名を path 用 ID として正規化する。
    static func normalizeRoomID(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RoomServiceError.invalidRoomName }
        let forbidden = CharacterSet(charactersIn: "/#$[]")
        guard trimmed.rangeOfCharacter(from: forbidden) == nil else {
            throw RoomServiceError.invalidRoomName
        }
        return trimmed
    }

    /// ルームを新規作成する。作成者がホストになる。
    /// 同名で meta だけ残った空室（メンバー0）は再利用のため先に削除する。
    static func createRoom(
        name: String,
        password: String?,
        hostMemberID: String
    ) async throws -> String {
        try ensureFirebaseConfigured()
        let roomID = try normalizeRoomID(name)
        let ref = metaReference(for: roomID)

        let snapshot = try await getSnapshot(ref)
        if snapshot.exists() {
            if try await isMembersEmpty(roomID: roomID) {
                try await removeValue(roomReference(for: roomID))
            } else {
                throw RoomServiceError.roomAlreadyExists
            }
        }

        let normalizedPassword = normalizedOptionalPassword(password)
        let meta = RoomMeta(
            name: roomID,
            password: normalizedPassword,
            createdAt: Date().timeIntervalSince1970,
            hostMemberID: hostMemberID
        )
        try await setValue(ref, meta.asFirebaseValue())
        return roomID
    }

    /// 既存ルームに参加する。meta が無いレガシー部屋はパスワードなしなら参加可。
    static func joinRoom(name: String, password: String?) async throws -> String {
        try ensureFirebaseConfigured()
        let roomID = try normalizeRoomID(name)
        let ref = metaReference(for: roomID)

        let snapshot = try await getSnapshot(ref)
        if !snapshot.exists() {
            let entered = (password ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard entered.isEmpty else { throw RoomServiceError.roomNotFound }
            return roomID
        }

        guard let meta = RoomMeta.fromFirebaseValue(snapshot.value, fallbackName: roomID) else {
            throw RoomServiceError.roomNotFound
        }
        guard meta.matches(password: password) else {
            throw RoomServiceError.wrongPassword
        }
        return roomID
    }

    /// ホスト不在の旧ルームなら、候補者をホストに設定する。
    static func ensureHostIfNeeded(roomID: String, candidateMemberID: String) async throws {
        try ensureFirebaseConfigured()
        let safeRoom = try normalizeRoomID(roomID)
        let ref = metaReference(for: safeRoom)
        let snapshot = try await getSnapshot(ref)
        guard snapshot.exists() else { return }
        guard var meta = RoomMeta.fromFirebaseValue(snapshot.value, fallbackName: safeRoom) else { return }
        if let existing = meta.hostMemberID, !existing.isEmpty { return }
        meta.hostMemberID = candidateMemberID
        try await setValue(ref, meta.asFirebaseValue())
    }

    /// ホストを別メンバーへ譲渡する（現ホストのみ）。
    static func transferHost(
        roomID: String,
        currentHostMemberID: String,
        newHostMemberID: String
    ) async throws {
        try ensureFirebaseConfigured()
        let safeRoom = try normalizeRoomID(roomID)
        let ref = metaReference(for: safeRoom)
        let snapshot = try await getSnapshot(ref)
        guard snapshot.exists(),
              var meta = RoomMeta.fromFirebaseValue(snapshot.value, fallbackName: safeRoom)
        else {
            throw RoomServiceError.roomNotFound
        }
        guard meta.hostMemberID == currentHostMemberID else {
            throw RoomServiceError.notHost
        }
        guard newHostMemberID != currentHostMemberID, !newHostMemberID.isEmpty else {
            throw RoomServiceError.invalidHostCandidate
        }
        meta.hostMemberID = newHostMemberID
        try await setValue(ref, meta.asFirebaseValue())
    }

    /// ルーム全体（meta / members / trigger）を削除して解散する。
    static func dissolveRoom(roomID: String) async throws {
        try ensureFirebaseConfigured()
        let safeRoom = try normalizeRoomID(roomID)
        try await removeValue(roomReference(for: safeRoom))
    }

    // MARK: - Members

    static func upsertMember(
        roomID: String,
        memberID: String,
        displayName: String,
        avatarEmoji: String
    ) async throws {
        try ensureFirebaseConfigured()
        let safeRoom = try normalizeRoomID(roomID)
        let member = RoomMember(
            id: memberID,
            displayName: displayName,
            avatarEmoji: avatarEmoji,
            joinedAt: Date().timeIntervalSince1970
        )
        try await setValue(memberReference(roomID: safeRoom, memberID: memberID), member.asFirebaseValue())
    }

    static func leaveMember(roomID: String, memberID: String) async throws {
        try ensureFirebaseConfigured()
        let safeRoom = try normalizeRoomID(roomID)
        try await removeValue(memberReference(roomID: safeRoom, memberID: memberID))
        // 最後のメンバーがいなくなったら部屋ごと消す（幽霊ルーム対策）
        if try await isMembersEmpty(roomID: safeRoom) {
            try await removeValue(roomReference(for: safeRoom))
        }
    }

    /// `members` 配下を監視する。戻り値のクロージャで停止する。
    @MainActor
    static func startListeningMembers(
        roomID: String,
        onUpdate: @escaping @MainActor ([RoomMember]) -> Void
    ) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            onUpdate([])
            return {}
        }
        guard let safeRoom = try? normalizeRoomID(roomID) else {
            onUpdate([])
            return {}
        }

        let ref = membersReference(for: safeRoom)
        ref.keepSynced(true)
        let handle = ref.observe(.value) { snapshot in
            var members: [RoomMember] = []
            for child in snapshot.children {
                guard let childSnap = child as? DataSnapshot,
                      let member = RoomMember.fromFirebaseValue(id: childSnap.key, value: childSnap.value)
                else { continue }
                members.append(member)
            }
            members.sort {
                if $0.joinedAt == $1.joinedAt { return $0.displayName < $1.displayName }
                return $0.joinedAt < $1.joinedAt
            }
            Task { @MainActor in
                onUpdate(members)
            }
        }
        return {
            ref.removeObserver(withHandle: handle)
            ref.keepSynced(false)
        }
    }

    /// `meta` を監視する。削除されたら `onUpdate(nil)`。
    @MainActor
    static func startListeningMeta(
        roomID: String,
        onUpdate: @escaping @MainActor (RoomMeta?) -> Void
    ) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else {
            onUpdate(nil)
            return {}
        }
        guard let safeRoom = try? normalizeRoomID(roomID) else {
            onUpdate(nil)
            return {}
        }

        let ref = metaReference(for: safeRoom)
        ref.keepSynced(true)
        let handle = ref.observe(.value) { snapshot in
            let meta: RoomMeta?
            if snapshot.exists() {
                meta = RoomMeta.fromFirebaseValue(snapshot.value, fallbackName: safeRoom)
            } else {
                meta = nil
            }
            Task { @MainActor in
                onUpdate(meta)
            }
        }
        return {
            ref.removeObserver(withHandle: handle)
            ref.keepSynced(false)
        }
    }

    // MARK: - Private

    private static func roomReference(for roomID: String) -> DatabaseReference {
        Database.database().reference(withPath: "rooms/\(roomID)")
    }

    private static func metaReference(for roomID: String) -> DatabaseReference {
        roomReference(for: roomID).child("meta")
    }

    private static func membersReference(for roomID: String) -> DatabaseReference {
        roomReference(for: roomID).child("members")
    }

    private static func memberReference(roomID: String, memberID: String) -> DatabaseReference {
        membersReference(for: roomID).child(memberID)
    }

    /// `members` が無い、または子が0なら空室とみなす。
    private static func isMembersEmpty(roomID: String) async throws -> Bool {
        let snapshot = try await getSnapshot(membersReference(for: roomID))
        return !snapshot.exists() || snapshot.childrenCount == 0
    }

    private static func ensureFirebaseConfigured() throws {
        guard FirebaseBootstrap.isConfigured else {
            throw RoomServiceError.firebaseNotConfigured
        }
    }

    private static func normalizedOptionalPassword(_ password: String?) -> String? {
        let trimmed = (password ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func getSnapshot(_ ref: DatabaseReference) async throws -> DataSnapshot {
        Database.database().goOnline()

        do {
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
                            continuation.resume(throwing: mapDatabaseError(error))
                        }
                    }
                )

                Task {
                    try? await Task.sleep(for: .seconds(12))
                    once.resume {
                        continuation.resume(throwing: RoomServiceError.networkUnavailable)
                    }
                }
            }
        } catch let error as RoomServiceError {
            throw error
        } catch {
            throw mapDatabaseError(error)
        }
    }

    private static func setValue(_ ref: DatabaseReference, _ value: Any) async throws {
        Database.database().goOnline()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ref.setValue(value) { error, _ in
                    if let error {
                        continuation.resume(throwing: mapDatabaseError(error))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch let error as RoomServiceError {
            throw error
        } catch {
            throw mapDatabaseError(error)
        }
    }

    private static func removeValue(_ ref: DatabaseReference) async throws {
        Database.database().goOnline()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                ref.removeValue { error, _ in
                    if let error {
                        continuation.resume(throwing: mapDatabaseError(error))
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
        } catch let error as RoomServiceError {
            throw error
        } catch {
            throw mapDatabaseError(error)
        }
    }

    /// Firebase コールバック（nonisolated）からも呼べるよう、MainActor に紐づけない。
    private nonisolated static func mapDatabaseError(_ error: Error) -> Error {
        let text = error.localizedDescription.lowercased()
        if text.contains("permission") || text.contains("permission_denied") {
            return RoomServiceError.permissionDenied
        }
        if text.contains("offline")
            || text.contains("network")
            || text.contains("timeout")
            || text.contains("timed out")
        {
            return RoomServiceError.networkUnavailable
        }
        return error
    }
}
