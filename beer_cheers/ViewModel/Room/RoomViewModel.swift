//
//  RoomViewModel.swift
//  beer_cheers
//
//  ルームタブの状態管理。作成・参加・退出・ホスト譲渡とメンバー一覧を担う。
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class RoomViewModel {
    var mode: RoomMode = .join
    var draftRoomName: String = ""
    var draftPassword: String = ""
    var errorMessage: String?
    var statusMessage: String?
    /// URL 招待の参加確認ダイアログ用。nil で非表示。
    var pendingInviteRoomID: String?
    /// 招待参加失敗時のアラート文言。nil で非表示。
    var inviteJoinFailureMessage: String?
    /// アラート閉じ時に pending が消えても参加処理が止まらないよう控える。
    private var inviteJoinRoomID: String?
    private(set) var isLoading = false
    private(set) var isMembersLoading = false
    private(set) var currentRoomID: String
    private(set) var members: [RoomMember] = []
    private(set) var hostMemberID: String?

    /// 部屋が変わったときに `AirCheersViewModel.switchRoom` へ橋渡しする。
    var onRoomChange: ((String) -> Void)?

    /// メンバー登録に使う表示名と絵文字（アカウント画面のプロフィールから供給）。
    var memberProfileProvider: () -> UserAccountProfile = {
        UserAccountProfile.default
    }

    private var stopMembersListening: (() -> Void)?
    private var stopMetaListening: (() -> Void)?
    private var pendingMembersSnapshot = false
    private var pendingMetaSnapshot = false
    private let memberID: String
    /// 自分から退出／解散するときのリモート meta 削除通知を無視する。
    private var isLeavingIntentionally = false
    /// Preview 用。true のとき Firebase 同期を行わない。
    private var usesRemoteSync = true

    init() {
        memberID = RoomSessionStore.stableMemberID()
        currentRoomID = RoomSessionStore.loadCurrentRoomID()
        draftRoomName = RoomSessionStore.isGuestRoomID(currentRoomID) ? "" : currentRoomID
    }

    var isOnGuestRoom: Bool { RoomSessionStore.isGuestRoomID(currentRoomID) }

    var isCurrentUserHost: Bool {
        guard let hostMemberID else { return false }
        return hostMemberID == memberID
    }

    var localMemberID: String { memberID }

    /// 自分を先頭にした表示用メンバー一覧。
    var displayMembers: [RoomMember] {
        members.sorted { lhs, rhs in
            if lhs.id == memberID { return true }
            if rhs.id == memberID { return false }
            if lhs.joinedAt == rhs.joinedAt {
                return lhs.displayName < rhs.displayName
            }
            return lhs.joinedAt < rhs.joinedAt
        }
    }

    func isHost(_ member: RoomMember) -> Bool {
        member.id == hostMemberID
    }

    func isLocalMember(_ member: RoomMember) -> Bool {
        member.id == memberID
    }

    func resumeMembershipIfNeeded() {
        guard usesRemoteSync else { return }
        guard !isOnGuestRoom else {
            stopAllObservation()
            members = []
            hostMemberID = nil
            isMembersLoading = false
            return
        }
        isMembersLoading = true
        Task {
            await registerCurrentMembership()
            startRoomObservation(for: currentRoomID)
        }
    }

    /// 退出。ホストならルーム解散、それ以外は自分だけ退出。
    func closeRoom() async {
        guard !isOnGuestRoom else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let leavingRoomID = currentRoomID
        let asHost = isCurrentUserHost
        isLeavingIntentionally = true
        stopAllObservation()

        do {
            if asHost {
                try await RoomService.dissolveRoom(roomID: leavingRoomID)
            } else {
                try await RoomService.leaveMember(roomID: leavingRoomID, memberID: memberID)
            }
        } catch {
            #if DEBUG
                print("[Room] closeRoom remote failed: \(error.localizedDescription)")
            #endif
        }

        moveToGuestLocally(
            status: asHost
                ? "ホストとしてルームを解散しました。"
                : "共有ルームを閉じました。"
        )
        isLeavingIntentionally = false
    }

    func joinRoom() async {
        await submitCreateOrJoin(isCreate: false, passwordPolicy: .requireMatch)
        if errorMessage == nil {
            statusMessage = "ルーム「\(currentRoomID)」に参加しました。"
        }
    }

    func createRoom() async {
        await submitCreateOrJoin(isCreate: true, passwordPolicy: .requireMatch)
        if errorMessage == nil {
            statusMessage = "ルーム「\(currentRoomID)」を作成して接続しました。"
        }
    }

    /// Deep Link / Universal Link から招待を提示する。
    func presentInvite(roomID: String) {
        let trimmed = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        do {
            let safe = try RoomID.normalize(trimmed)
            if !isOnGuestRoom, currentRoomID == safe {
                pendingInviteRoomID = nil
                inviteJoinRoomID = nil
                errorMessage = nil
                statusMessage = "すでにこのルームにいます。"
                return
            }
            errorMessage = nil
            pendingInviteRoomID = safe
            inviteJoinRoomID = safe
        } catch {
            pendingInviteRoomID = nil
            inviteJoinRoomID = nil
            errorMessage = (error as? RoomServiceError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// アラートの dismiss 用。参加ボタン後も `inviteJoinRoomID` は残す。
    func clearPendingInvite() {
        pendingInviteRoomID = nil
    }

    /// キャンセル時は参加予約も破棄する。
    func cancelPendingInvite() {
        pendingInviteRoomID = nil
        inviteJoinRoomID = nil
    }

    /// URL 招待経路で入室する（パスワード不要）。
    func joinViaInvite() async {
        // アラート dismiss で pending が消えても、控えがあれば参加できる。
        guard let inviteRoomID = inviteJoinRoomID ?? pendingInviteRoomID else { return }
        pendingInviteRoomID = nil
        inviteJoinFailureMessage = nil
        draftRoomName = inviteRoomID
        await submitCreateOrJoin(isCreate: false, passwordPolicy: .inviteURL)
        if errorMessage == nil {
            inviteJoinRoomID = nil
            statusMessage = "ルーム「\(currentRoomID)」に参加しました。"
        } else {
            // 失敗時は再試行できるよう控えを残し、アラートで明示する。
            inviteJoinRoomID = inviteRoomID
            inviteJoinFailureMessage = errorMessage
        }
    }

    func dismissInviteJoinFailure() {
        inviteJoinFailureMessage = nil
    }

    /// 招待参加の失敗アラートから再試行する。
    func retryInviteJoin() async {
        inviteJoinFailureMessage = nil
        await joinViaInvite()
    }

    /// 現在ルームの共有テキスト（ゲストでは nil）。
    var inviteShareText: String? {
        guard !isOnGuestRoom else { return nil }
        return RoomInviteURL.makeShareText(roomID: currentRoomID)
    }

    func copyInviteLinkToPasteboard() {
        guard let text = inviteShareText else { return }
        UIPasteboard.general.string = text
        statusMessage = "招待リンクをコピーしました。"
        errorMessage = nil
    }

    func transferHost(to member: RoomMember) async {
        guard !isOnGuestRoom else { return }
        guard isCurrentUserHost else {
            errorMessage = RoomServiceError.notHost.errorDescription
            return
        }
        guard member.id != memberID else { return }

        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        // Preview などリモート無しではローカル状態だけ更新（再入室はしない）
        if !usesRemoteSync {
            hostMemberID = member.id
            statusMessage = "\(member.displayName) をホストにしました。"
            return
        }

        do {
            // meta.hostMemberID のみ更新。ルームへの再参加は行わない。
            try await RoomService.transferHost(
                roomID: currentRoomID,
                currentHostMemberID: memberID,
                newHostMemberID: member.id
            )
            hostMemberID = member.id
            statusMessage = "\(member.displayName) をホストにしました。"
        } catch let error as RoomServiceError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = mapGenericError(error)
        }
    }

    // MARK: - Private

    private func submitCreateOrJoin(
        isCreate: Bool,
        passwordPolicy: RoomJoinPasswordPolicy
    ) async {
        errorMessage = nil
        statusMessage = nil
        isLoading = true
        defer { isLoading = false }

        let password = draftPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        let optionalPassword: String? = password.isEmpty ? nil : password
        let previousRoomID = currentRoomID
        let wasHost = isCurrentUserHost

        do {
            let roomID: String
            if isCreate {
                roomID = try await RoomService.createRoom(
                    name: draftRoomName,
                    password: optionalPassword,
                    hostMemberID: memberID
                )
            } else {
                roomID = try await RoomService.joinRoom(
                    name: draftRoomName,
                    password: optionalPassword,
                    passwordPolicy: passwordPolicy
                )
            }

            if !RoomSessionStore.isGuestRoomID(previousRoomID), previousRoomID != roomID {
                isLeavingIntentionally = true
                stopAllObservation()
                if wasHost {
                    try? await RoomService.dissolveRoom(roomID: previousRoomID)
                } else {
                    try? await RoomService.leaveMember(roomID: previousRoomID, memberID: memberID)
                }
                isLeavingIntentionally = false
            }

            applyRoomID(roomID)
            if isCreate {
                hostMemberID = memberID
            }
            await registerCurrentMembership()
            startRoomObservation(for: roomID)
        } catch let error as RoomServiceError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = mapGenericError(error)
        }
    }

    private func applyRoomID(_ roomID: String) {
        currentRoomID = roomID
        draftRoomName = roomID
        draftPassword = ""
        RoomSessionStore.saveCurrentRoomID(roomID)
        onRoomChange?(roomID)
    }

    private func moveToGuestLocally(status: String) {
        let guestID = RoomSessionStore.assignGuestRoomID()
        currentRoomID = guestID
        draftRoomName = ""
        draftPassword = ""
        members = []
        hostMemberID = nil
        isMembersLoading = false
        statusMessage = status
        onRoomChange?(guestID)
    }

    private func handleRemoteRoomDissolved() {
        guard !isOnGuestRoom, !isLeavingIntentionally else { return }
        stopAllObservation()
        moveToGuestLocally(status: "ホストがルームを閉じたため、退出しました。")
    }

    private func registerCurrentMembership() async {
        guard !isOnGuestRoom else { return }
        let profile = memberProfileProvider()
        do {
            try await RoomService.upsertMember(
                roomID: currentRoomID,
                memberID: memberID,
                nickname: profile.nickname,
                username: profile.username,
                avatarURL: profile.avatarURL,
                avatarEmoji: profile.avatarEmoji
            )
            try await RoomService.ensureHostIfNeeded(
                roomID: currentRoomID,
                candidateMemberID: memberID
            )
        } catch {
            #if DEBUG
                print("[Room] register membership failed: \(error.localizedDescription)")
            #endif
            if errorMessage == nil {
                errorMessage = mapGenericError(error)
            }
        }
    }

    private func startRoomObservation(for roomID: String) {
        stopAllObservation()
        guard !RoomSessionStore.isGuestRoomID(roomID) else {
            members = []
            hostMemberID = nil
            isMembersLoading = false
            return
        }

        isMembersLoading = true
        pendingMembersSnapshot = true
        pendingMetaSnapshot = true

        stopMembersListening = RoomService.startListeningMembers(roomID: roomID) { [weak self] list in
            guard let self else { return }
            self.members = list
            self.pendingMembersSnapshot = false
            self.refreshMembersLoadingState()
        }
        stopMetaListening = RoomService.startListeningMeta(roomID: roomID) { [weak self] meta in
            guard let self else { return }
            self.pendingMetaSnapshot = false
            if let meta {
                self.hostMemberID = meta.hostMemberID
                self.refreshMembersLoadingState()
            } else {
                self.isMembersLoading = false
                self.handleRemoteRoomDissolved()
            }
        }
    }

    private func refreshMembersLoadingState() {
        isMembersLoading = pendingMembersSnapshot || pendingMetaSnapshot
    }

    private func stopAllObservation() {
        stopMembersListening?()
        stopMembersListening = nil
        stopMetaListening?()
        stopMetaListening = nil
        pendingMembersSnapshot = false
        pendingMetaSnapshot = false
    }

    private func mapGenericError(_ error: Error) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("permission") {
            return RoomServiceError.permissionDenied.errorDescription ?? error.localizedDescription
        }
        if text.contains("offline") || text.contains("network") {
            return RoomServiceError.networkUnavailable.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }
}

#if DEBUG
extension RoomViewModel {
    /// Preview 用に共有ルーム状態を差し込む（Firebase 同期はしない）。
    func applyPreviewOccupiedRoom(
        roomID: String,
        hostMemberID: String?,
        members: [RoomMember],
        isMembersLoading: Bool = false
    ) {
        usesRemoteSync = false
        stopAllObservation()
        currentRoomID = roomID
        draftRoomName = roomID
        self.hostMemberID = hostMemberID
        self.members = members
        self.isMembersLoading = isMembersLoading
        errorMessage = nil
        statusMessage = nil
    }

    static func previewWithMultipleMembers() -> RoomViewModel {
        let vm = RoomViewModel()
        let me = vm.localMemberID
        let now = Date().timeIntervalSince1970
        vm.applyPreviewOccupiedRoom(
            roomID: "weekend_cheers",
            hostMemberID: me,
            members: [
                RoomMember(id: me, nickname: "自分", username: "me", avatarURL: nil, avatarEmoji: "🍺", joinedAt: now - 30),
                RoomMember(id: "m_taro", nickname: "たろう", username: "taro", avatarURL: nil, avatarEmoji: "🍻", joinedAt: now - 20),
                RoomMember(id: "m_hanako", nickname: "はなこ", username: "hanako", avatarURL: nil, avatarEmoji: "🥂", joinedAt: now - 10),
                RoomMember(id: "m_jiro", nickname: "じろう", username: "jiro", avatarURL: nil, avatarEmoji: "🥃", joinedAt: now - 5),
                RoomMember(id: "m_saburo", nickname: "さぶろう", username: "saburo", avatarURL: nil, avatarEmoji: "🍷", joinedAt: now),
            ]
        )
        return vm
    }

    static func previewMembersLoading() -> RoomViewModel {
        let vm = RoomViewModel()
        vm.applyPreviewOccupiedRoom(
            roomID: "weekend_cheers",
            hostMemberID: nil,
            members: [],
            isMembersLoading: true
        )
        return vm
    }
}
#endif
