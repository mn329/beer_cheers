//
//  RoomFormCard.swift
//  beer_cheers
//
//  ルーム作成・参加フォーム。
//

import SwiftUI

struct RoomFormCard: View {
    @Bindable var viewModel: RoomViewModel
    var focusedField: FocusState<RoomView.Field?>.Binding
    var onJoinRequested: () -> Void

    var body: some View {
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
                    .focused(focusedField, equals: .roomName)
                    .submitLabel(.next)
                    .onSubmit { focusedField.wrappedValue = .password }
                    .disabled(viewModel.isLoading)
            }

            labeledField(title: "パスワード（任意・名前参加時のみ）") {
                SecureField("未設定可", text: $viewModel.draftPassword)
                    .textContentType(.password)
                    .focused(focusedField, equals: .password)
                    .submitLabel(.done)
                    .onSubmit { requestPrimaryAction() }
                    .disabled(viewModel.isLoading)
            }

            Button {
                focusedField.wrappedValue = nil
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
            .disabled(
                viewModel.isLoading
                    || viewModel.draftRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )

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
            "新しいルームを作ります。作成した人がホストになります。パスワードは名前参加時だけ使われます。"
        case .join:
            "ルーム名で参加します。パスワード付きの場合のみ入力してください（招待 URL からは不要です）。"
        }
    }

    private func requestPrimaryAction() {
        switch viewModel.mode {
        case .create:
            Task { await viewModel.createRoom() }
        case .join:
            onJoinRequested()
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
