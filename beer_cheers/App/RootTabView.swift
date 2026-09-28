//
//  RootTabView.swift
//  beer_cheers
//
//  乾杯・ルーム・アカウントを切り替える下部 TabView。
//  初回以外のプロフィール設定は fullScreenCover で表示し、キャンセル時はアカウントタブへ戻す。
//  使い方ガイドは実際のタブの上に重ね、ステップに合わせてタブを切り替える。
//

import SwiftUI

struct RootTabView: View {
    @Bindable var cheersViewModel: AirCheersViewModel
    @Bindable var accountViewModel: AccountViewModel
    @State private var roomViewModel = RoomViewModel()
    @State private var selection: TabID = .cheers
    /// 同一 URL の連続配信で二重ダイアログにならないようにする。
    @State private var lastHandledInviteURL: URL?
    @State private var tutorial = TutorialProgress()

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
                    AccountView(viewModel: accountViewModel, onShowTutorial: startTutorial)
                }
                .extendsUnderFloatingTabBar()
            }
        }
        .toolbarBackgroundVisibility(.hidden, for: .tabBar)
        .accessibilityHidden(tutorial.isActive)
        .overlay {
            if let step = tutorial.step {
                TutorialCoachOverlay(
                    step: step,
                    isMotionAvailable: cheersViewModel.isMotionAvailable,
                    didPracticeCheers: tutorial.didPracticeCheers,
                    onNext: advanceTutorial,
                    onSkip: finishTutorial
                )
            }
        }
        .onChange(of: cheersViewModel.localCheersCount) {
            tutorial.recordLocalCheers()
        }
        .fullScreenCover(isPresented: Binding(
            get: { accountViewModel.needsProfileSetup },
            set: { _ in }
        )) {
            ProfileSetupView(
                viewModel: accountViewModel,
                onFinished: {
                    roomViewModel.resumeMembershipIfNeeded()
                    selection = .account
                },
                onCancelled: {
                    selection = .account
                }
            )
        }
        .onAppear {
            accountViewModel.startObservingAuthState()
            cheersViewModel.ensureWatchConnectivity()
            let cheersVM = cheersViewModel
            let accountVM = accountViewModel
            cheersVM.switchRoom(to: roomViewModel.currentRoomID)
            roomViewModel.onRoomChange = { [weak cheersVM] newRoomID in
                cheersVM?.switchRoom(to: newRoomID)
            }
            roomViewModel.memberProfileProvider = { [weak accountVM] in
                accountVM?.profile ?? UserAccountProfile.default
            }
            roomViewModel.resumeMembershipIfNeeded()
            DispatchQueue.main.async {
                cheersViewModel.startRemoteTriggerListening()
            }
            if !tutorial.isActive, !TutorialStore.hasCompleted() {
                startTutorial()
            }
        }
        .onOpenURL { url in
            if accountViewModel.handleIncomingAuthURL(url) {
                return
            }
            handleIncomingInviteURL(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            handleIncomingInviteURL(url)
        }
    }

    // MARK: - Tutorial

    private func startTutorial() {
        tutorial.start()
        applyTutorialStep()
    }

    private func advanceTutorial() {
        tutorial.advance()
        if tutorial.isActive {
            applyTutorialStep()
        } else {
            finishTutorial()
        }
    }

    private func finishTutorial() {
        tutorial.finish()
        TutorialStore.markCompleted()
        cheersViewModel.isPracticeMode = false
        selection = .cheers
    }

    private func applyTutorialStep() {
        guard let step = tutorial.step else { return }
        cheersViewModel.isPracticeMode = true
        selection = step == .room ? .room : .cheers
    }

    // MARK: - Invite

    private func handleIncomingInviteURL(_ url: URL) {
        if let last = lastHandledInviteURL, last == url {
            return
        }
        guard let roomID = RoomInviteURL.parse(url) else { return }
        lastHandledInviteURL = url
        // 招待から来た人は入室が目的なので、ガイドは閉じて参加確認を優先する
        if tutorial.isActive {
            finishTutorial()
        }
        selection = .room
        roomViewModel.presentInvite(roomID: roomID)
    }
}

#Preview {
    RootTabView(
        cheersViewModel: AirCheersViewModel(),
        accountViewModel: AccountViewModel()
    )
}
