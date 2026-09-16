//
//  RootTabView.swift
//  beer_cheers
//
//  乾杯・ルーム・アカウントを切り替える下部 TabView。
//  iOS 26 以降は TabView がデフォルトで Liquid Glass の見た目になり、タブバーはコンテンツ上に浮く。
//  ルーム画面で部屋を作成・参加したら、AirCheersViewModel に切替を伝播するよう結線する。
//  Realtime DB の乾杯トリガ監視はここで開始し、乾杯タブ以外でも更新を受け取れるようにする。
//

import SwiftUI

struct RootTabView: View {
    @Bindable var cheersViewModel: AirCheersViewModel
    @State private var roomViewModel = RoomViewModel()
    @State private var accountViewModel = AccountViewModel()
    @State private var selection: TabID = .cheers

    /// SwiftUI の `Tab` ビューと名前衝突しないよう、選択肢には別名を付ける。
    enum TabID: Hashable {
        case cheers
        case room
        case account
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("乾杯", systemImage: "wineglass.fill", value: TabID.cheers) {
                CheersView(viewModel: cheersViewModel)
                    .extendsUnderFloatingTabBar()
            }

            Tab("ルーム", systemImage: "person.2.fill", value: TabID.room) {
                RoomView(viewModel: roomViewModel)
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
            let accountVM = accountViewModel
            cheersVM.switchRoom(to: roomViewModel.currentRoomID)
            roomViewModel.onRoomChange = { [weak cheersVM] newRoomID in
                cheersVM?.switchRoom(to: newRoomID)
            }
            roomViewModel.memberProfileProvider = { [weak accountVM] in
                let profile = accountVM?.profile ?? UserAccountProfile.default
                return (profile.displayName, profile.avatarEmoji)
            }
            roomViewModel.resumeMembershipIfNeeded()
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
