//
//  FakeRoomRepository.swift
//  beer_cheersTests
//

import Foundation
@testable import beer_cheers

/// Firebase を使わずに `RoomViewModel` を動かすための差し替え実装。
/// 呼ばれた操作を記録し、監視のコールバックをテストから発火できる。
final class FakeRoomRepository: RoomRepositorying {
    enum Call: Equatable {
        case createRoom(name: String, hostMemberID: String)
        case joinRoom(name: String, policy: RoomJoinPasswordPolicy)
        case ensureHost(roomID: String)
        case transferHost(roomID: String, to: String)
        case dissolveRoom(roomID: String)
        case upsertMember(roomID: String, memberID: String)
        case leaveMember(roomID: String, memberID: String)
    }

    private(set) var calls: [Call] = []
    /// 作成・参加時に投げるエラー。nil なら成功して入力名をそのまま ID として返す。
    var roomOperationError: Error?
    var transferHostError: Error?
    /// `fetchMembers` が返すルーム別のメンバー。未設定のルームは取得失敗として扱う。
    var fetchedMembers: [String: [RoomMember]] = [:]
    private(set) var fetchMembersCallCount = 0

    private var membersListeners: [String: @MainActor ([RoomMember]) -> Void] = [:]
    private var metaListeners: [String: @MainActor (RoomMeta?) -> Void] = [:]

    func createRoom(name: String, password: String?, hostMemberID: String) async throws -> String {
        calls.append(.createRoom(name: name, hostMemberID: hostMemberID))
        if let roomOperationError { throw roomOperationError }
        return try RoomID.normalize(name)
    }

    func joinRoom(name: String, password: String?, passwordPolicy: RoomJoinPasswordPolicy) async throws -> String {
        calls.append(.joinRoom(name: name, policy: passwordPolicy))
        if let roomOperationError { throw roomOperationError }
        return try RoomID.normalize(name)
    }

    func ensureHostIfNeeded(roomID: String, candidateMemberID: String) async throws {
        calls.append(.ensureHost(roomID: roomID))
    }

    func transferHost(roomID: String, currentHostMemberID: String, newHostMemberID: String) async throws {
        calls.append(.transferHost(roomID: roomID, to: newHostMemberID))
        if let transferHostError { throw transferHostError }
    }

    func dissolveRoom(roomID: String) async throws {
        calls.append(.dissolveRoom(roomID: roomID))
    }

    func upsertMember(
        roomID: String,
        memberID: String,
        nickname: String,
        username: String,
        avatarURL: String?,
        avatarEmoji: String
    ) async throws {
        calls.append(.upsertMember(roomID: roomID, memberID: memberID))
    }

    func leaveMember(roomID: String, memberID: String) async throws {
        calls.append(.leaveMember(roomID: roomID, memberID: memberID))
    }

    func fetchMembers(roomID: String) async throws -> [RoomMember] {
        fetchMembersCallCount += 1
        guard let members = fetchedMembers[roomID] else { throw RoomRepositoryError.networkUnavailable }
        return members
    }

    func startListeningMembers(
        roomID: String,
        onUpdate: @escaping @MainActor ([RoomMember]) -> Void
    ) -> () -> Void {
        membersListeners[roomID] = onUpdate
        return { [weak self] in self?.membersListeners[roomID] = nil }
    }

    func startListeningMeta(
        roomID: String,
        onUpdate: @escaping @MainActor (RoomMeta?) -> Void
    ) -> () -> Void {
        metaListeners[roomID] = onUpdate
        return { [weak self] in self?.metaListeners[roomID] = nil }
    }

    private var connectionListener: (@MainActor (Bool) -> Void)?

    func startListeningConnection(onChange: @escaping @MainActor (Bool) -> Void) -> () -> Void {
        connectionListener = onChange
        return { [weak self] in self?.connectionListener = nil }
    }

    // MARK: - テストからの発火

    func emitConnection(_ isConnected: Bool) {
        connectionListener?(isConnected)
    }

    func upsertCount(roomID: String, memberID: String) -> Int {
        calls.filter { $0 == .upsertMember(roomID: roomID, memberID: memberID) }.count
    }

    func isListening(roomID: String) -> Bool {
        membersListeners[roomID] != nil && metaListeners[roomID] != nil
    }

    func emitMembers(_ members: [RoomMember], roomID: String) {
        membersListeners[roomID]?(members)
    }

    func emitMeta(_ meta: RoomMeta?, roomID: String) {
        metaListeners[roomID]?(meta)
    }
}
