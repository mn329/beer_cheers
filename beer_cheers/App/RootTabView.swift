//
//  RootTabView.swift
//  beer_cheers
//
//  乾杯画面とアカウント画面を切り替える下部 TabView。
//  iOS 26 以降は TabView がデフォルトで Liquid Glass の見た目になり、タブバーはコンテンツ上に浮く。
//  アカウント画面で部屋 ID を変更したら、AirCheersViewModel に切替を伝播するよう結線する。
//  Realtime DB の乾杯トリガ監視はここで開始し、乾杯タブ以外でも更新を受け取れるようにする。
//

import SwiftUI

struct RootTabView: View {
    @Bindable var cheersViewModel: AirCheersViewModel
    @State private var accountViewModel = AccountViewModel()
    @State private var selection: TabID = .cheers

    /// SwiftUI の `Tab` ビューと名前衝突しないよう、選択肢には別名を付ける。
    enum TabID: Hashable {
        case cheers
        case account
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("乾杯", systemImage: "wineglass.fill", value: TabID.cheers) {
                CheersView(viewModel: cheersViewModel)
                    .extendsUnderFloatingTabBar()
            }

            Tab("アカウント", systemImage: "person.crop.circle", value: TabID.account) {
                NavigationStack {
                    AccountView(viewModel: accountViewModel)
                }
                .extendsUnderFloatingTabBar()
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
        .onAppear {
            accountViewModel.startObservingAuthState()
            let cheersVM = cheersViewModel
            cheersVM.switchRoom(to: accountViewModel.roomID) // 起動時にアカウントのルームIDを反映
            accountViewModel.onRoomChange = { [weak cheersVM] newRoomID in
                cheersVM?.switchRoom(to: newRoomID)
            }
            // リモート乾杯の監視はタブに依存させない（アカウント表示中も Firebase の更新を受け取る）
            DispatchQueue.main.async {
                cheersViewModel.startRemoteTriggerListening()
            }
        }
    }
}

#Preview {
    RootTabView(cheersViewModel: AirCheersViewModel())
}
