//
//  AccountView.swift
//  beer_cheers
//
//  アカウント画面のルート（これから一緒に実装します）
//

import SwiftUI

struct AccountView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ZStack{
            AppBackground()
            ScrollView {
                VStack(spacing: 18){
                    AccountHeaderView(profile: viewModel.profile)
                        .padding(.top, 8)
                    ProfileSection(viewModel: viewModel)
                    RoomSection(viewModel: viewModel)
                    AuthSection(viewModel: viewModel)
                    AboutSection()
                }
            }
            .contentMargins(
                .bottom,
                TabContentLayout.floatingTabBarClearance,
                for: .scrollContent
            )
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            viewModel.refreshAuthState()
        }
    }
}

#Preview {
    NavigationStack {
        AccountView(viewModel: AccountViewModel())
    }
}
