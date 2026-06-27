//
//  AccountHeaderView.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/05/18.
//

import SwiftUI

struct AccountHeaderView: View {
    let profile: UserAccountProfile
    var body: some View {
        HStack(spacing: 16){
            Text(profile.avatarEmoji)
                .font(.system(size: 56))
                .frame(width: 84, height: 84)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.18))
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 4){
                Text(profile.displayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AccountContentStyle.primary)
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
