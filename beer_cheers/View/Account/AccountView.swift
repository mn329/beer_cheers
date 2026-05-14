//
//  AccountView.swift
//  beer_cheers
//
//  アカウント画面のルート。プロフィール / ルーム / 認証 / アプリ情報のセクションを束ねる。
//  背景は乾杯画面と同じ AppBackground を敷き、Liquid Glass に映えるように透過させる。
//

import SwiftUI

struct AccountView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    AccountHeaderView(profile: viewModel.profile)
                        .padding(.top, 8)
                    ProfileSection(viewModel: viewModel)
                    RoomSection(viewModel: viewModel)
                    AuthSection(viewModel: viewModel)
                    AboutSection()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AccountView(viewModel: AccountViewModel())
    }
}
