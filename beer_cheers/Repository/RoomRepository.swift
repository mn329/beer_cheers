//
//  RoomRepository.swift
//  beer_cheers
//
//  Realtime Database の `rooms/{roomID}/meta`・`members` を扱う Repository。
//

import FirebaseDatabase
import Foundation

/// `RoomViewModel` が依存するルーム操作。テストでは Firebase を使わない実装に差し替える。
protocol RoomRepositorying {
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
    /// `members` 配下を監視する。戻り値のクロージャで停止する。
    func startListeningMembers(roomID: String, onUpdate: @escaping @MainActor ([RoomMember]) -> Void) -> () -> Void
    /// `meta` を監視する。削除されたら `onUpdate(nil)`。戻り値のクロージャで停止する。
    func startListeningMeta(roomID: String, onUpdate: @escaping @MainActor (RoomMeta?) -> Void) -> () -> Void
}

struct RoomRepository: RoomRepositorying {
    /// ルームを新規作成する。作成者がホストになる。
    func createRoom(
        name: String,
        password: String?,
        hostMemberID: String
    ) async throws -> String {
        try Self.ensureFirebaseConfigured()
        let roomID = try RoomID.normalize(name)
        let ref = Self.metaReference(for: roomID)

        let snapshot = try await Self.getSnapshot(ref)
        if snapshot.exists() {
            throw RoomRepositoryError.roomAlreadyExists
        }

        let meta = RoomMeta(
            name: roomID,
            password: Self.normalizedOptionalPassword(password),
            createdAt: Date().timeIntervalSince1970,
            hostMemberID: hostMemberID
        )
        try await Self.setValue(ref, meta.asFirebaseValue())
        return roomID
    }

    /// 既存ルームに参加する。
    /// - `requireMatch`: meta 無しレガシー部屋はパスワードなしなら参加可。パスワード付きは照合。
    /// - `inviteURL`: meta 必須。パスワードは見ない。
    func joinRoom(
        name: String,
        password: String?,
        passwordPolicy: RoomJoinPasswordPolicy
    ) async throws -> String {
        try Self.ensureFirebaseConfigured()
        let roomID = try RoomID.normalize(name)
        let snapshot = try await Self.getSnapshot(Self.metaReference(for: roomID))
        if !snapshot.exists() {
            switch passwordPolicy {
            case .inviteURL:
                throw RoomRepositoryError.roomNotFound
            case .requireMatch:
                guard Self.normalizedOptionalPassword(password) == nil else {
                    throw RoomRepositoryError.roomNotFound
                }
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
    func ensureHostIfNeeded(roomID: String, candidateMemberID: String) async throws {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        let ref = Self.metaReference(for: safeRoom)
        let snapshot = try await Self.getSnapshot(ref)
        guard snapshot.exists() else { return }
        guard var meta = RoomMeta.fromFirebaseValue(snapshot.value, fallbackName: safeRoom) else { return }
        if let existing = meta.hostMemberID, !existing.isEmpty { return }
        meta.hostMemberID = candidateMemberID
        try await Self.setValue(ref, meta.asFirebaseValue())
    }

    /// ホストを別メンバーへ譲渡する（現ホストのみ）。
    func transferHost(
        roomID: String,
        currentHostMemberID: String,
        newHostMemberID: String
    ) async throws {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        let ref = Self.metaReference(for: safeRoom)
        let snapshot = try await Self.getSnapshot(ref)
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
        try await Self.setValue(ref, meta.asFirebaseValue())
    }

    /// ルーム全体（meta / members / trigger）を削除して解散する。
    func dissolveRoom(roomID: String) async throws {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        try await Self.removeValue(Self.roomReference(for: safeRoom))
    }

    // MARK: - Members

    func upsertMember(
        roomID: String,
        memberID: String,
        nickname: String,
        username: String,
        avatarURL: String?,
        avatarEmoji: String
    ) async throws {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        let member = RoomMember(
            id: memberID,
            nickname: nickname,
            username: username,
            avatarURL: avatarURL,
            avatarEmoji: avatarEmoji,
            joinedAt: Date().timeIntervalSince1970
        )
        try await Self.setValue(
            Self.memberReference(roomID: safeRoom, memberID: memberID),
            member.asFirebaseValue()
        )
    }

    func leaveMember(roomID: String, memberID: String) async throws {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        try await Self.removeValue(Self.memberReference(roomID: safeRoom, memberID: memberID))
    }

    // MARK: - Listening

    func startListeningMembers(
        roomID: String,
        onUpdate: @escaping @MainActor ([RoomMember]) -> Void
    ) -> () -> Void {
        guard FirebaseBootstrap.isConfigured, let safeRoom = try? RoomID.normalize(roomID) else {
            onUpdate([])
            return {}
        }

        let ref = Self.membersReference(for: safeRoom)
        ref.keepSynced(true)
        let handle = ref.observe(.value) { snapshot in
            var members: [RoomMember] = []
            for child in snapshot.children {
                guard let childSnap = child as? DataSnapshot,
                      let member = RoomMember.fromFirebaseValue(id: childSnap.key, value: childSnap.value)
                else { continue }
                members.append(member)
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

    func startListeningMeta(
        roomID: String,
        onUpdate: @escaping @MainActor (RoomMeta?) -> Void
    ) -> () -> Void {
        guard FirebaseBootstrap.isConfigured, let safeRoom = try? RoomID.normalize(roomID) else {
            onUpdate(nil)
            return {}
        }

        let ref = Self.metaReference(for: safeRoom)
        ref.keepSynced(true)
        let handle = ref.observe(.value) { snapshot in
            let meta = snapshot.exists()
                ? RoomMeta.fromFirebaseValue(snapshot.value, fallbackName: safeRoom)
                : nil
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
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }

    private static func setValue(_ ref: DatabaseReference, _ value: Any) async throws {
        do {
            try await RealtimeDatabaseClient.setValue(ref, value)
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }

    private static func removeValue(_ ref: DatabaseReference) async throws {
        do {
            try await RealtimeDatabaseClient.removeValue(ref)
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }
}

/// Firebase の生エラーを画面に出せる `RoomRepositoryError` に寄せる。判別できないものはそのまま返す。
nonisolated func mapRoomDatabaseError(_ error: Error) -> Error {
    if error is RoomRepositoryError { return error }
    let text = error.localizedDescription.lowercased()
    if text.contains("permission") {
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
