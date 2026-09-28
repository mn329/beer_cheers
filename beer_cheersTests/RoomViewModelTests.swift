//
//  RoomViewModelTests.swift
//  beer_cheersTests
//

import Foundation
import Testing
@testable import beer_cheers

/// Firebase の代わりに `FakeRoomRepository` を注入し、ルーム操作による画面状態の変化を確かめる。
final class RoomViewModelTests {
    private let suiteName = "RoomViewModelTests.\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let repository = FakeRoomRepository()
    private let viewModel: RoomViewModel
    private var roomChanges: [String] = []

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        viewModel = RoomViewModel(repository: repository, defaults: defaults)
        viewModel.onRoomChange = { [weak self] in self?.roomChanges.append($0) }
    }

    deinit {
        // deinit は MainActor 外で走るため、非 Sendable の `defaults` ではなく Sendable な suiteName から消す
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private var memberID: String { viewModel.localMemberID }

    private func join(_ name: String) async {
        viewModel.draftRoomName = name
        await viewModel.joinRoom()
    }

    private func create(_ name: String) async {
        viewModel.draftRoomName = name
        await viewModel.createRoom()
    }

    private func member(_ id: String, joinedAt: TimeInterval) -> RoomMember {
        RoomMember(id: id, nickname: id, username: "", avatarURL: nil, avatarEmoji: "🍺", joinedAt: joinedAt)
    }

    // MARK: - 初期状態

    @Test func startsInGuestRoom() {
        #expect(viewModel.isOnGuestRoom)
        #expect(viewModel.inviteShareText == nil)
    }

    // MARK: - 作成・参加

    @Test func creatingRoomMakesMeHostAndStartsSync() async {
        await create("weekend")

        #expect(viewModel.currentRoomID == "weekend")
        #expect(viewModel.isCurrentUserHost)
        #expect(viewModel.errorMessage == nil)
        #expect(roomChanges == ["weekend"])
        #expect(repository.calls.contains(.upsertMember(roomID: "weekend", memberID: memberID)))
        #expect(repository.isListening(roomID: "weekend"))
    }

    @Test func joinedRoomIsRestoredOnNextLaunch() async {
        await join("weekend")

        #expect(RoomSessionStore.loadCurrentRoomID(defaults: defaults) == "weekend")
    }

    @Test func failedJoinShowsErrorAndStaysInGuestRoom() async {
        repository.roomOperationError = RoomRepositoryError.wrongPassword

        await join("weekend")

        #expect(viewModel.isOnGuestRoom)
        #expect(viewModel.errorMessage == RoomRepositoryError.wrongPassword.errorDescription)
        #expect(roomChanges.isEmpty)
    }

    @Test func movingToAnotherRoomLeavesThePreviousOne() async {
        await join("first")

        await join("second")

        #expect(repository.calls.contains(.leaveMember(roomID: "first", memberID: memberID)))
        #expect(!repository.isListening(roomID: "first"))
        #expect(repository.isListening(roomID: "second"))
    }

    @Test func hostMovingToAnotherRoomDissolvesThePreviousOne() async {
        await create("first")

        await join("second")

        #expect(repository.calls.contains(.dissolveRoom(roomID: "first")))
    }

    // MARK: - 退出・解散

    @Test func hostClosingRoomDissolvesIt() async {
        await create("weekend")

        await viewModel.closeRoom()

        #expect(repository.calls.contains(.dissolveRoom(roomID: "weekend")))
        #expect(viewModel.isOnGuestRoom)
        #expect(!repository.isListening(roomID: "weekend"))
    }

    @Test func memberClosingRoomOnlyLeaves() async {
        await join("weekend")

        await viewModel.closeRoom()

        #expect(repository.calls.contains(.leaveMember(roomID: "weekend", memberID: memberID)))
        #expect(!repository.calls.contains(.dissolveRoom(roomID: "weekend")))
        #expect(viewModel.isOnGuestRoom)
    }

    @Test func roomDissolvedByHostMovesMeToGuestRoom() async {
        await join("weekend")

        repository.emitMeta(nil, roomID: "weekend")

        #expect(viewModel.isOnGuestRoom)
        #expect(viewModel.statusMessage == "ホストがルームを閉じたため、退出しました。")
        #expect(roomChanges.last.map(RoomSessionStore.isGuestRoomID) == true)
    }

    // MARK: - メンバー

    @Test func membersListShowsMeFirstThenByJoinOrder() async {
        await join("weekend")

        repository.emitMembers(
            [member("m_late", joinedAt: 30), member(memberID, joinedAt: 20), member("m_early", joinedAt: 10)],
            roomID: "weekend"
        )

        #expect(viewModel.displayMembers.map(\.id) == [memberID, "m_early", "m_late"])
    }

    @Test func membersStayLoadingUntilBothMembersAndMetaArrive() async {
        await join("weekend")
        #expect(viewModel.isMembersLoading)

        repository.emitMembers([member(memberID, joinedAt: 1)], roomID: "weekend")
        #expect(viewModel.isMembersLoading)

        repository.emitMeta(
            RoomMeta(name: "weekend", password: nil, createdAt: 1, hostMemberID: memberID),
            roomID: "weekend"
        )
        #expect(!viewModel.isMembersLoading)
        #expect(viewModel.isCurrentUserHost)
    }

    // MARK: - 再接続

    /// 再登録は Task で走るため、MainActor に順番を譲りながら条件が満たされるのを待つ。
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }

    @Test func reconnectingAfterDisconnectRegistersMemberAgain() async {
        viewModel.resumeMembershipIfNeeded()
        await join("weekend")
        repository.emitConnection(false)
        repository.emitConnection(true)
        #expect(repository.upsertCount(roomID: "weekend", memberID: memberID) == 1)

        repository.emitConnection(false)
        repository.emitConnection(true)
        await waitUntil { repository.upsertCount(roomID: "weekend", memberID: memberID) == 2 }

        #expect(repository.upsertCount(roomID: "weekend", memberID: memberID) == 2)
    }

    @Test func reconnectingInGuestRoomDoesNotRegister() async {
        viewModel.resumeMembershipIfNeeded()
        repository.emitConnection(true)

        repository.emitConnection(false)
        repository.emitConnection(true)
        await waitUntil { !repository.calls.isEmpty }

        #expect(repository.calls.isEmpty)
    }

    // MARK: - ホスト譲渡

    @Test func hostCanTransferHostToAnotherMember() async {
        await create("weekend")
        let other = member("m_other", joinedAt: 1)

        await viewModel.transferHost(to: other)

        #expect(repository.calls.contains(.transferHost(roomID: "weekend", to: "m_other")))
        #expect(viewModel.isHost(other))
        #expect(!viewModel.isCurrentUserHost)
    }

    @Test func nonHostCannotTransferHost() async {
        await join("weekend")

        await viewModel.transferHost(to: member("m_other", joinedAt: 1))

        #expect(viewModel.errorMessage == RoomRepositoryError.notHost.errorDescription)
        #expect(!repository.calls.contains(where: {
            if case .transferHost = $0 { true } else { false }
        }))
    }

    // MARK: - 招待リンク

    @Test func inviteToCurrentRoomDoesNotAskAgain() async {
        await join("weekend")

        viewModel.presentInvite(roomID: "weekend")

        #expect(viewModel.pendingInviteRoomID == nil)
        #expect(viewModel.statusMessage == "すでにこのルームにいます。")
    }

    @Test func inviteWithInvalidRoomNameShowsError() {
        viewModel.presentInvite(roomID: "a.b")

        #expect(viewModel.pendingInviteRoomID == nil)
        #expect(viewModel.errorMessage == RoomRepositoryError.invalidRoomName.errorDescription)
    }

    @Test func joiningViaInviteSkipsPasswordCheck() async {
        viewModel.presentInvite(roomID: "weekend")

        await viewModel.joinViaInvite()

        #expect(repository.calls.contains(.joinRoom(name: "weekend", policy: .inviteURL)))
        #expect(viewModel.currentRoomID == "weekend")
    }
}
