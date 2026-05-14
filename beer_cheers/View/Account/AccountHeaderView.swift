//
//  AccountHeaderView.swift
//  beer_cheers
//
//  画面上部のプロフィール・カード。アイコン絵文字と表示名を Liquid Glass 上に並べる。
//

import SwiftUI

struct AccountHeaderView: View {
    let profile: UserAccountProfile

    var body: some View {
        HStack(spacing: 16) {
            Text(profile.avatarEmoji)
                .font(.system(size: 56))
                .frame(width: 84, height: 84)
                .background(
                    Circle()
                        .fill(.white.opacity(0.18))
                )
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.45), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("カンパイ仲間")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(GlassCardBackground())
    }
}

#Preview {
    AccountHeaderView(profile: .default)
        .padding()
        .background(AppBackground())
}
