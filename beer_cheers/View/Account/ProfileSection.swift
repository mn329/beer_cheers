//
//  ProfileSection.swift
//  beer_cheers
//
//  プロフィール編集。画像はタップで変更（上に変更できることが分かるオーバーレイ）。
//

import PhotosUI
import SwiftUI
import UIKit

struct ProfileSection: View {
    @Bindable var viewModel: AccountViewModel
    @State private var draftUsername = ""
    @State private var draftNickname = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @FocusState private var focusedField: Field?

    private enum Field { case username, nickname }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "プロフィール", systemImage: "person.circle")

            if viewModel.authState.isSignedIn {
                signedInEditor
            } else {
                guestNote
            }

            if let message = viewModel.profileErrorMessage, viewModel.authState.isSignedIn {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.error)
            }
        }
        .padding(16)
        .background(GlassCardBackground())
        .onAppear(perform: refreshDrafts)
        .onChange(of: viewModel.profile) { _, _ in refreshDrafts() }
        .onChange(of: viewModel.authState.isSignedIn) { _, signedIn in
            if !signedIn {
                selectedItem = nil
                selectedImage = nil
                refreshDrafts()
            }
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
    }

    private var guestNote: some View {
        Text("ゲストの表示名は「ゲスト」です。サインインするとユーザー名・ニックネーム・画像を設定できます。")
            .font(.footnote)
            .foregroundStyle(AccountContentStyle.secondary)
    }

    private var signedInEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer(minLength: 0)
                tappableAvatar
                Spacer(minLength: 0)
            }

            labeledField(title: "ユーザー名", caption: ProfileFieldValidator.usernameRuleCaption) {
                TextField("beer_fan", text: $draftUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .username)
            }

            labeledField(title: "ニックネーム") {
                TextField("たろう", text: $draftNickname)
                    .focused($focusedField, equals: .nickname)
            }

            HStack {
                Spacer()
                Button {
                    Task { await save() }
                } label: {
                    if viewModel.isProfileSaving {
                        ProgressView()
                            .tint(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                    } else {
                        Text("保存")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.9))
                .foregroundStyle(.black)
                .disabled(viewModel.isProfileSaving)
            }
        }
    }

    private var tappableAvatar: some View {
        // PhotosPicker の label は nonisolated のため、MainActor の値は先に取り出す
        let previewImage = selectedImage
        let avatarURL = viewModel.profile.avatarURL
        let avatarEmoji = viewModel.profile.avatarEmoji
        let isSaving = viewModel.isProfileSaving

        return PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())
                } else {
                    ProfileAvatarView(
                        avatarURL: avatarURL,
                        avatarEmoji: avatarEmoji,
                        size: 96,
                        emojiSize: 44
                    )
                }

                Circle()
                    .fill(Color.black.opacity(0.38))
                    .frame(width: 96, height: 96)

                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                    Text("変更")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 96, height: 96)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white.opacity(0.65), lineWidth: 2)
            )
            .accessibilityLabel("プロフィール画像を変更")
        }
        .disabled(isSaving)
        .buttonStyle(.plain)
    }

    private func labeledField<Content: View>(
        title: String,
        caption: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(AccountContentStyle.secondary)
            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AccountContentStyle.secondary.opacity(0.9))
            }
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(GlassFieldBackground())
                .foregroundStyle(AccountContentStyle.primary)
        }
    }

    private func refreshDrafts() {
        draftUsername = viewModel.profile.username
        draftNickname = viewModel.profile.nickname
    }

    private func save() async {
        focusedField = nil
        if let image = selectedImage {
            let ok = await viewModel.completeProfile(
                username: draftUsername,
                nickname: draftNickname,
                image: image
            )
            if ok { selectedImage = nil }
            return
        }

        _ = await viewModel.saveProfileFields(
            username: draftUsername,
            nickname: draftNickname
        )
    }
}

#Preview {
    ZStack {
        AppBackground()
        ProfileSection(viewModel: AccountViewModel())
            .padding()
    }
}
