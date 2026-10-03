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
    /// `members` 配下を 1 回だけ読む（監視はしない）。最近のルームの参加者表示用。
    func fetchMembers(roomID: String) async throws -> [RoomMember]
    /// `members` 配下を監視する。戻り値のクロージャで停止する。
    func startListeningMembers(roomID: String, onUpdate: @escaping @MainActor ([RoomMember]) -> Void) -> () -> Void
    /// `meta` を監視する。削除されたら `onUpdate(nil)`。戻り値のクロージャで停止する。
    func startListeningMeta(roomID: String, onUpdate: @escaping @MainActor (RoomMeta?) -> Void) -> () -> Void
    /// サーバーとの接続状態を監視する。戻り値のクロージャで停止する。
    func startListeningConnection(onChange: @escaping @MainActor (Bool) -> Void) -> () -> Void
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
    /// 同時に入室した複数人が互いに上書きしないよう、`hostMemberID` をトランザクションで書く。
    func ensureHostIfNeeded(roomID: String, candidateMemberID: String) async throws {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        // meta の無いレガシー部屋に hostMemberID だけ作るとルールの検証で拒否されるため、先に存在を確かめる
        guard try await Self.getSnapshot(Self.metaReference(for: safeRoom)).exists() else { return }
        _ = try await Self.runTransaction(Self.hostReference(for: safeRoom)) { current in
            if let existing = current.value as? String, !existing.isEmpty {
                return TransactionResult.abort()
            }
            current.value = candidateMemberID
            return TransactionResult.success(withValue: current)
        }
    }

    /// ホストを別メンバーへ譲渡する（現ホストのみ）。
    /// 読んでから書くまでに他の人が譲渡しても上書きしないよう、トランザクションで現ホストを確かめて書く。
    func transferHost(
        roomID: String,
        currentHostMemberID: String,
        newHostMemberID: String
    ) async throws {
        try Self.ensureFirebaseConfigured()
        guard newHostMemberID != currentHostMemberID, !newHostMemberID.isEmpty else {
            throw RoomRepositoryError.invalidHostCandidate
        }
        let safeRoom = try RoomID.normalize(roomID)
        guard try await Self.getSnapshot(Self.metaReference(for: safeRoom)).exists() else {
            throw RoomRepositoryError.roomNotFound
        }
        let result = try await Self.runTransaction(Self.hostReference(for: safeRoom)) { current in
            // ローカルキャッシュが無い初回は値が空で呼ばれる。空のまま返すとサーバー値と食い違い、実際の値で再実行される
            guard let host = current.value as? String else {
                return TransactionResult.success(withValue: current)
            }
            guard host == currentHostMemberID else {
                return TransactionResult.abort()
            }
            current.value = newHostMemberID
            return TransactionResult.success(withValue: current)
        }
        // 実際にホストが空だった場合も空のまま確定するため、確定後の値で判定する
        guard result?.value as? String == newHostMemberID else {
            throw RoomRepositoryError.notHost
        }
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
        let ref = Self.memberReference(roomID: safeRoom, memberID: memberID)
        try await Self.setValue(ref, member.asFirebaseValue())
        // 「閉じる」を押さずにアプリを終了・圏外になった人がメンバー一覧に残り続けないようにする。
        // 切断時操作は一度実行されると消えるため、再接続のたびに upsertMember し直す（RoomViewModel 側）
        do {
            try await RealtimeDatabaseClient.removeOnDisconnect(ref)
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }

    func leaveMember(roomID: String, memberID: String) async throws {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        let ref = Self.memberReference(roomID: safeRoom, memberID: memberID)
        RealtimeDatabaseClient.cancelDisconnectOperations(ref)
        try await Self.removeValue(ref)
    }

    // MARK: - Listening

    func fetchMembers(roomID: String) async throws -> [RoomMember] {
        try Self.ensureFirebaseConfigured()
        let safeRoom = try RoomID.normalize(roomID)
        let snapshot = try await Self.getSnapshot(Self.membersReference(for: safeRoom))
        // 非同期コンテキストでは NSEnumerator の for-in が使えないため allObjects を使う
        return snapshot.children.allObjects.compactMap { child in
            guard let childSnap = child as? DataSnapshot else { return nil }
            return RoomMember.fromFirebaseValue(id: childSnap.key, value: childSnap.value)
        }
    }

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

    func startListeningConnection(onChange: @escaping @MainActor (Bool) -> Void) -> () -> Void {
        guard FirebaseBootstrap.isConfigured else { return {} }
        return RealtimeDatabaseClient.observeConnection(onChange: onChange)
    }

    // MARK: - Private

    private static func runTransaction(
        _ ref: DatabaseReference,
        update: @escaping @Sendable (MutableData) -> TransactionResult
    ) async throws -> DataSnapshot? {
        do {
            return try await RealtimeDatabaseClient.runTransaction(ref, update: update)
        } catch {
            throw mapRoomDatabaseError(error)
        }
    }

    private static func hostReference(for roomID: String) -> DatabaseReference {
        metaReference(for: roomID).child("hostMemberID")
    }

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
