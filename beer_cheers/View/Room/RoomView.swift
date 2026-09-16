//
//  RoomView.swift
//  beer_cheers
//
//  ルーム作成・参加タブ。同一画面でモードを切り替え、ルーム名と任意パスワードを扱う。
//

import SwiftUI

struct RoomView: View {
    @Bindable var viewModel: RoomViewModel
    @FocusState private var focusedField: Field?
    @State private var showJoinConfirm = false
    @State private var showCloseConfirm = false
    @State private var showMembersSheet = false
    @State private var hostTransferTarget: RoomMember?

    private enum Field {
        case roomName
        case password
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        currentRoomCard
                        formCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .contentMargins(
                    .bottom,
                    TabContentLayout.floatingTabBarClearance,
                    for: .scrollContent
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("ルーム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .onAppear {
                viewModel.resumeMembershipIfNeeded()
            }
            .alert("ルームに参加", isPresented: $showJoinConfirm) {
                Button("参加する") {
                    Task { await viewModel.joinRoom() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("ルーム「\(viewModel.draftRoomName)」に参加しますか？")
            }
            .alert("ルームを閉じる", isPresented: $showCloseConfirm) {
                Button(viewModel.isCurrentUserHost ? "解散する" : "閉じる", role: .destructive) {
                    Task { await viewModel.closeRoom() }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(closeConfirmMessage)
            }
            .alert(
                "ホストを変更",
                isPresented: Binding(
                    get: { hostTransferTarget != nil },
                    set: { if !$0 { hostTransferTarget = nil } }
                )
            ) {
                Button("変更する") {
                    if let target = hostTransferTarget {
                        Task { await viewModel.transferHost(to: target) }
                    }
                    hostTransferTarget = nil
                }
                Button("キャンセル", role: .cancel) {
                    hostTransferTarget = nil
                }
            } message: {
                if let target = hostTransferTarget {
                    Text("\(target.displayName) をホストにしますか？")
                }
            }
            .sheet(isPresented: $showMembersSheet) {
                membersListSheet
            }
        }
    }

    private var closeConfirmMessage: String {
        if viewModel.isCurrentUserHost {
            "ホストのためルーム「\(viewModel.currentRoomID)」を解散します。参加中の全員が退出します。"
        } else {
            "ルーム「\(viewModel.currentRoomID)」を閉じますか？この端末だけ部屋を離れます。"
        }
    }

    // MARK: - Cards

    private var currentRoomCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "現在のルーム", systemImage: "dot.radiowaves.left.and.right")
            Text(
                viewModel.isOnGuestRoom
                    ? "まだ共有ルームには入っていません。下から作成または参加してください。"
                    : "同じルームにいる端末同士で乾杯できます。"
            )
                .font(.footnote)
                .foregroundStyle(AccountContentStyle.secondary)

            if viewModel.isOnGuestRoom {
                Text("-----")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AccountContentStyle.secondary)
            } else {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentRoomID)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AccountContentStyle.primary)
                            .textSelection(.enabled)

                        if viewModel.isMembersLoading && hostDisplayName == nil {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.mini)
                                Text("ホスト情報を読み込み中…")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AccountContentStyle.secondary)
                            }
                        } else if let hostName = hostDisplayName {
                            Text(viewModel.isCurrentUserHost ? "ホスト: \(hostName)（あなた）" : "ホスト: \(hostName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AccountContentStyle.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        focusedField = nil
                        showCloseConfirm = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AccountContentStyle.error.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("ルームを閉じる")
                    .disabled(viewModel.isLoading)
                }

                membersSection
            }

            if viewModel.isOnGuestRoom, let status = viewModel.statusMessage {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.secondary)
            }
        }
        .padding(16)
        .background(GlassCardBackground())
    }

    private var hostDisplayName: String? {
        guard let hostID = viewModel.hostMemberID else { return nil }
        if let member = viewModel.displayMembers.first(where: { $0.id == hostID }) {
            return member.displayName
        }
        return nil
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(
                    viewModel.isMembersLoading
                        ? "参加メンバー"
                        : "参加メンバー（\(viewModel.displayMembers.count)）"
                )
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AccountContentStyle.secondary)
                Spacer(minLength: 0)
            }

            Button {
                showMembersSheet = true
            } label: {
                membersStripContent
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("メンバー一覧を開く")
        }
    }

    @ViewBuilder
    private var membersStripContent: some View {
        if viewModel.isMembersLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("メンバーを読み込み中…")
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.secondary)
                Spacer(minLength: 0)
            }
        } else if viewModel.displayMembers.isEmpty {
            Text("タップしてメンバーを確認")
                .font(.footnote)
                .foregroundStyle(AccountContentStyle.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.displayMembers) { member in
                        memberAvatar(member, size: 40, emojiSize: 24)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var membersListSheet: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if viewModel.isMembersLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.1)
                            Text("メンバーを読み込み中…")
                                .font(.subheadline)
                                .foregroundStyle(AccountContentStyle.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if viewModel.displayMembers.isEmpty {
                        Text("まだメンバーはいません。")
                            .font(.footnote)
                            .foregroundStyle(AccountContentStyle.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(viewModel.displayMembers) { member in
                                    memberRow(member)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white.opacity(0.18))
                                        )
                                }

                                if viewModel.isCurrentUserHost,
                                   viewModel.displayMembers.contains(where: { $0.id != viewModel.localMemberID })
                                {
                                    Text("他のメンバーを選ぶとホストを譲渡できます。")
                                        .font(.caption)
                                        .foregroundStyle(AccountContentStyle.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.top, 4)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            .padding(.bottom, 28)
                        }
                    }
                }
            }
            .navigationTitle("参加メンバー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        showMembersSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationContentInteraction(.scrolls)
    }

    @ViewBuilder
    private func memberRow(_ member: RoomMember) -> some View {
        let isHost = viewModel.isHost(member)
        let isLocal = viewModel.isLocalMember(member)
        let canTransfer = viewModel.isCurrentUserHost && !isLocal

        let row = HStack(spacing: 12) {
            memberAvatar(member, size: 40, emojiSize: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(member.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(AccountContentStyle.primary)
                    if isLocal {
                        Text("自分")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AccountContentStyle.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.white.opacity(0.28))
                            )
                    }
                }
                if isHost {
                    Text("ホスト")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AccountContentStyle.secondary)
                } else if canTransfer {
                    Text("タップしてホストにする")
                        .font(.caption2)
                        .foregroundStyle(AccountContentStyle.secondary)
                }
            }
            Spacer(minLength: 0)
            if isHost {
                Image(systemName: "crown.fill")
                    .font(.footnote)
                    .foregroundStyle(Color(red: 0.85, green: 0.62, blue: 0.12))
            }
        }

        if canTransfer {
            Button {
                hostTransferTarget = member
            } label: {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    private func memberAvatar(_ member: RoomMember, size: CGFloat, emojiSize: CGFloat) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(member.avatarEmoji)
                .font(.system(size: emojiSize))
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.45))
                )
            if viewModel.isHost(member) {
                Image(systemName: "crown.fill")
                    .font(.system(size: max(10, size * 0.28)))
                    .foregroundStyle(Color(red: 0.85, green: 0.62, blue: 0.12))
                    .offset(x: 2, y: -2)
            }
        }
        .accessibilityLabel(memberAccessibilityLabel(member))
    }

    private func memberAccessibilityLabel(_ member: RoomMember) -> String {
        var parts = [member.displayName]
        if viewModel.isLocalMember(member) { parts.append("自分") }
        if viewModel.isHost(member) { parts.append("ホスト") }
        return parts.joined(separator: "、")
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "作成・参加", systemImage: "person.2.fill")

            Picker("モード", selection: $viewModel.mode) {
                ForEach(RoomMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isLoading)

            Text(modeHelpText)
                .font(.footnote)
                .foregroundStyle(AccountContentStyle.secondary)

            labeledField(title: "ルーム名") {
                TextField("例: weekend_cheers", text: $viewModel.draftRoomName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .roomName)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .disabled(viewModel.isLoading)
            }

            labeledField(title: "パスワード（任意）") {
                SecureField("未設定可", text: $viewModel.draftPassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { requestPrimaryAction() }
                    .disabled(viewModel.isLoading)
            }

            Button {
                focusedField = nil
                requestPrimaryAction()
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(viewModel.mode.actionTitle)
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.9))
            .foregroundStyle(.black)
            .disabled(viewModel.isLoading || viewModel.draftRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let status = viewModel.statusMessage {
                Text(status)
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.secondary)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.error)
            }
        }
        .padding(16)
        .background(GlassCardBackground())
    }

    private var modeHelpText: String {
        switch viewModel.mode {
        case .create:
            "新しいルームを作ります。作成した人がホストになります。"
        case .join:
            "既存のルームに入ります。パスワード付きの場合のみ入力してください。"
        }
    }

    private func requestPrimaryAction() {
        switch viewModel.mode {
        case .create:
            Task { await viewModel.createRoom() }
        case .join:
            showJoinConfirm = true
        }
    }

    private func labeledField<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AccountContentStyle.secondary)
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GlassFieldBackground())
                .foregroundStyle(AccountContentStyle.primary)
        }
    }
}

#Preview("未参加") {
    RoomView(viewModel: RoomViewModel())
}

#Preview("複数メンバー") {
    RoomView(viewModel: .previewWithMultipleMembers())
}

#Preview("メンバー読み込み中") {
    RoomView(viewModel: .previewMembersLoading())
}
