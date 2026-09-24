//
//  RoomRepository.swift
//  beer_cheers
//
//  Realtime Database の `rooms/{roomID}/meta`・`members` を扱う Repository。
//

import FirebaseDatabase
import Foundation

protocol RoomRepositorying: Sendable {
    func createRoom(name: String, password: String?, hostMemberID: String) async throws -> String
    func joinRoom(name: String, password: String?, passwordPolicy: RoomJoinPasswordPolicy) async throws -> String
    func ensureHostIfNeeded(roomID: String, candidateMemberID: String) async throws
    func transferHost(roomID: String, currentHostMemberID: String, newHostMemberID: String) async throws
    func dissolveRoom(roomID: String) async throws
    func upsertMember(
        roomID: String,
        memberID: String,
        nickname: String,
        username: String,
        avatarURL: String?,
        avatarEmoji: String
    ) async throws
    func leaveMember(roomID: String, memberID: String) async throws
}

enum RoomRepository {
    /// ルーム名を path 用 ID として正規化する。
    static func normalizeRoomID(_ raw: String) throws -> String {
        try RoomID.normalize(raw)
    }

    /// ルームを新規作成する。作成者がホストになる。
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
            throw RoomRepositoryError.roomAlreadyExists
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

    /// 既存ルームに参加する。
    /// - `requireMatch`: meta 無しレガシー部屋はパスワードなしなら参加可。パスワード付きは照合。
    /// - `inviteURL`: meta 必須。パスワードは見ない。
    static func joinRoom(
        name: String,
        password: String?,
        passwordPolicy: RoomJoinPasswordPolicy = .requireMatch
    ) async throws -> String {
        try ensureFirebaseConfigured()
        let roomID = try normalizeRoomID(name)
        let ref = metaReference(for: roomID)

        let snapshot = try await getSnapshot(ref)
        if !snapshot.exists() {
            switch passwordPolicy {
            case .inviteURL:
                throw RoomRepositoryError.roomNotFound
            case .requireMatch:
                let entered = (password ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard entered.isEmpty else { throw RoomRepositoryError.roomNotFound }
                return roomID
            }
        }

        guard let meta = RoomMeta.fromFirebaseValue(snapshot.value, fallbackName: roomID) else {
            throw RoomRepositoryError.roomNotFound
        }
        switch passwordPolicy {
        case .inviteURL:
            return roomID
        case .requireMatch:
            guard meta.matches(password: password) else {
                throw RoomRepositoryError.wrongPassword
            }
            return roomID
        }
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
            throw RoomRepositoryError.roomNotFound
        }
        guard meta.hostMemberID == currentHostMemberID else {
            throw RoomRepositoryError.notHost
        }
        guard newHostMemberID != currentHostMemberID, !newHostMemberID.isEmpty else {
            throw RoomRepositoryError.invalidHostCandidate
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
        nickname: String,
        username: String,
        avatarURL: String?,
        avatarEmoji: String
    ) async throws {
        try ensureFirebaseConfigured()
        let safeRoom = try normalizeRoomID(roomID)
        let member = RoomMember(
            id: memberID,
            nickname: nickname,
            username: username,
            avatarURL: avatarURL,
            avatarEmoji: avatarEmoji,
            joinedAt: Date().timeIntervalSince1970
        )
        try await setValue(memberReference(roomID: safeRoom, memberID: memberID), member.asFirebaseValue())
    }

    static func leaveMember(roomID: String, memberID: String) async throws {
        try ensureFirebaseConfigured()
        let safeRoom = try normalizeRoomID(roomID)
        try await removeValue(memberReference(roomID: safeRoom, memberID: memberID))
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

    private static func ensureFirebaseConfigured() throws {
        guard FirebaseBootstrap.isConfigured else {
            throw RoomRepositoryError.firebaseNotConfigured
        }
    }

    private static func normalizedOptionalPassword(_ password: String?) -> String? {
        let trimmed = (password ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func getSnapshot(_ ref: DatabaseReference) async throws -> DataSnapshot {
        do {
            return try await RealtimeDatabaseClient.getSnapshot(
                ref,
                timeout: .seconds(12),
                timeoutError: RoomRepositoryError.networkUnavailable
            )
        } catch let error as RoomRepositoryError {
            throw error
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }

    private static func setValue(_ ref: DatabaseReference, _ value: Any) async throws {
        do {
            try await RealtimeDatabaseClient.setValue(ref, value)
        } catch let error as RoomRepositoryError {
            throw error
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }

    private static func removeValue(_ ref: DatabaseReference) async throws {
        do {
            try await RealtimeDatabaseClient.removeValue(ref)
        } catch let error as RoomRepositoryError {
            throw error
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }
}

/// 移行期間用の別名（既存呼び出しを段階的に置換するため）。
typealias RoomService = RoomRepository

/// Firebase コールバックからも呼べるよう、ファイルスコープの nonisolated にする。
nonisolated private func mapRoomDatabaseError(_ error: Error) -> Error {
    let text = error.localizedDescription.lowercased()
    if text.contains("permission") || text.contains("permission_denied") {
        return RoomRepositoryError.permissionDenied
    }
    if text.contains("offline")
        || text.contains("network")
        || text.contains("timeout")
        || text.contains("timed out")
    {
        return RoomRepositoryError.networkUnavailable
    }
    return error
}
