//
//  AccountHeaderView.swift
//  beer_cheers
//

import SwiftUI

struct AccountHeaderView: View {
    let profile: UserAccountProfile
    var isSignedIn: Bool = false
    var showsChevron: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            ProfileAvatarView(
                avatarURL: isSignedIn ? profile.avatarURL : nil,
                avatarEmoji: profile.avatarEmoji,
                size: 88,
                emojiSize: 42
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.55), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 6) {
                Text(isSignedIn ? profile.nickname : "ゲスト")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AccountContentStyle.primary)

                if isSignedIn, !profile.username.isEmpty {
                    Text("@\(profile.username)")
                        .font(.subheadline)
                        .foregroundStyle(AccountContentStyle.secondary)
                } else {
                    Text(isSignedIn ? "ユーザー名未設定" : "サインインするとプロフィールを表示します")
                        .font(.caption)
                        .foregroundStyle(AccountContentStyle.secondary)
                }

                if showsChevron {
                    Text("タップして編集")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AccountContentStyle.secondary.opacity(0.9))
                }
            }

            Spacer(minLength: 0)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AccountContentStyle.secondary)
            }
        }
        .padding(16)
        .background(GlassCardBackground())
    }
}

#Preview("signed in") {
    AccountHeaderView(
        profile: UserAccountProfile(
            username: "beer_fan",
            nickname: "たろう",
            avatarURL: "https://picsum.photos/200",
            avatarEmoji: "🍺"
        ),
        isSignedIn: true,
        showsChevron: true
    )
    .padding()
    .background(AppBackground())
}

#Preview("guest") {
    AccountHeaderView(profile: .placeholder, isSignedIn: false)
        .padding()
        .background(AppBackground())
}
