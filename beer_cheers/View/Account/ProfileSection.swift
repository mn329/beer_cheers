//
//  ProfileSection.swift
//  beer_cheers
//
//  表示名とアイコン絵文字を編集するセクション。
//

import SwiftUI

struct ProfileSection: View {
    @Bindable var viewModel: AccountViewModel

    @State private var draftDisplayName: String = ""
    @State private var draftAvatarEmoji: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case displayName, avatar }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "プロフィール", systemImage: "person.crop.circle")

            VStack(alignment: .leading, spacing: 6) {
                Text("表示名")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                TextField("表示名", text: $draftDisplayName)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .displayName)
                    .submitLabel(.done)
                    .onSubmit { commitDisplayName() }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(GlassFieldBackground())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("アイコン絵文字（1文字）")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                TextField("🍺", text: $draftAvatarEmoji)
                    .focused($focusedField, equals: .avatar)
                    .submitLabel(.done)
                    .onSubmit { commitAvatar() }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(GlassFieldBackground())
                    .foregroundStyle(.white)
            }

            HStack {
                Spacer()
                Button {
                    commitDisplayName()
                    commitAvatar()
                    focusedField = nil
                } label: {
                    Text("保存")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.9))
                .foregroundStyle(.black)
            }
        }
        .padding(16)
        .background(GlassCardBackground())
        .onAppear(perform: refreshDrafts)
        .onChange(of: viewModel.profile) { _, _ in refreshDrafts() }
    }

    private func refreshDrafts() {
        draftDisplayName = viewModel.profile.displayName
        draftAvatarEmoji = viewModel.profile.avatarEmoji
    }

    private func commitDisplayName() {
        viewModel.updateDisplayName(draftDisplayName)
    }

    private func commitAvatar() {
        viewModel.updateAvatarEmoji(draftAvatarEmoji)
    }
}

#Preview {
    ZStack {
        AppBackground()
        ProfileSection(viewModel: AccountViewModel())
            .padding()
    }
}
