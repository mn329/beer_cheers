//
//  ProfileSetupView.swift
//  beer_cheers
//
//  サインイン後の必須プロフィール（ユーザー名・ニックネーム・画像）。
//

import PhotosUI
import SwiftUI
import UIKit

struct ProfileSetupView: View {
    @Bindable var viewModel: AccountViewModel
    var onFinished: () -> Void
    var onCancelled: () -> Void = {}

    @State private var draftUsername = ""
    @State private var draftNickname = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @FocusState private var focusedField: Field?

    private enum Field { case username, nickname }

    var body: some View {
        ZStack {
            AppBackground()

            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .center, spacing: 8) {
                                Text("プロフィール設定")
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(.black)
                                    .frame(maxWidth: .infinity)

                                Text("ユーザー名・ニックネーム・画像は必須です。\nルームのメンバー一覧に表示されます。")
                                    .font(.subheadline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.black.opacity(0.72))
                                    .frame(maxWidth: .infinity)
                            }

                            avatarPicker

                            fieldBlock(title: "ユーザー名", caption: ProfileFieldValidator.usernameRuleCaption) {
                                TextField("beer_fan", text: $draftUsername)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .username)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .nickname }
                            }

                            fieldBlock(title: "ニックネーム", caption: "ルームで大きく表示されます") {
                                TextField("たろう", text: $draftNickname)
                                    .focused($focusedField, equals: .nickname)
                                    .submitLabel(.done)
                                    .onSubmit { focusedField = nil }
                            }

                            if let message = viewModel.profileErrorMessage {
                                Text(message)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AccountContentStyle.error)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                HStack {
                                    if viewModel.isProfileSaving {
                                        ProgressView()
                                            .tint(.black)
                                    }
                                    Text("保存してはじめる")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white.opacity(0.95))
                            .foregroundStyle(.black)
                            .disabled(viewModel.isProfileSaving)

                            Button {
                                Task { await cancelAndGoBack() }
                            } label: {
                                Text("戻る")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(.black.opacity(0.55))
                                    .frame(maxWidth: .infinity)
                            }
                            .disabled(viewModel.isProfileSaving)
                            .padding(.top, 4)

                            Text("戻るとサインイン情報は削除されます")
                                .font(.caption2)
                                .foregroundStyle(.black.opacity(0.4))
                                .frame(maxWidth: .infinity)
                        }
                        .padding(20)
                        .background(GlassCardBackground())
                        .padding(.horizontal, 24)

                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .onAppear {
            if draftUsername.isEmpty { draftUsername = viewModel.profile.username }
            if draftNickname.isEmpty,
               viewModel.profile.nickname != UserAccountProfile.default.nickname {
                draftNickname = viewModel.profile.nickname
            }
            viewModel.profileErrorMessage = nil
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                    if viewModel.profileErrorMessage == "プロフィール画像を選んでください" {
                        viewModel.profileErrorMessage = nil
                    }
                } else {
                    viewModel.profileErrorMessage = "画像を読み込めませんでした"
                }
            }
        }
    }

    private var avatarPicker: some View {
        let previewImage = selectedImage
        let hasSelectedImage = previewImage != nil
        let isSaving = viewModel.isProfileSaving

        return VStack(spacing: 12) {
            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 96, height: 96)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.black.opacity(0.55))
                        }
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Text(hasSelectedImage ? "写真を変更" : "写真を選ぶ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.bordered)
            .tint(.black)
            .disabled(isSaving)
        }
        .frame(maxWidth: .infinity)
    }

    private func fieldBlock<Content: View>(
        title: String,
        caption: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.black.opacity(0.62))
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GlassFieldBackground())
                .foregroundStyle(.black)
        }
    }

    private func submit() async {
        focusedField = nil
        viewModel.profileErrorMessage = nil

        if selectedImage == nil {
            viewModel.profileErrorMessage = "プロフィール画像を選んでください"
            return
        }
        if let usernameError = ProfileFieldValidator.validateUsername(draftUsername) {
            viewModel.profileErrorMessage = usernameError
            return
        }
        if let nicknameError = ProfileFieldValidator.validateNickname(draftNickname) {
            viewModel.profileErrorMessage = nicknameError
            return
        }

        guard let image = selectedImage else { return }
        let ok = await viewModel.completeProfile(
            username: draftUsername,
            nickname: draftNickname,
            image: image
        )
        if ok {
            onFinished()
        }
    }

    private func cancelAndGoBack() async {
        focusedField = nil
        draftUsername = ""
        draftNickname = ""
        selectedItem = nil
        selectedImage = nil
        await viewModel.cancelIncompleteRegistration()
        onCancelled()
    }
}

#Preview {
    ProfileSetupView(viewModel: AccountViewModel(), onFinished: {})
}
