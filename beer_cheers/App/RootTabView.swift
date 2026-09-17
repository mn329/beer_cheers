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
        ZStack(alignment: .top) {
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

            if let message = cheersViewModel.remoteSyncErrorMessage {
                remoteSyncErrorBanner(message)
                    .safeAreaPadding(.top, 8)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: cheersViewModel.remoteSyncErrorMessage)
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
            // 同期で監視開始し、起動直後の振る操作で notInRoom バナーが出ないようにする
            // （タブ非依存で Firebase 更新を受け取る）
            cheersViewModel.startRemoteTriggerListening()
        }
    }

    private func remoteSyncErrorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AccountContentStyle.error.opacity(0.92))
            )
            .accessibilityLabel(message)
    }
}

#Preview {
    RootTabView(cheersViewModel: AirCheersViewModel())
}
