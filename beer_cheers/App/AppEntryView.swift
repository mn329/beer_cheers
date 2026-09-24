//
//  AppEntryView.swift
//  beer_cheers
//
//  起動時に泡パーティクルを生成するあいだローディングを表示し、
//  初回はスタートフロー、初回サインイン後のみ必須プロフィールをここで表示。
//  本体表示後のプロフィール設定は RootTabView 側で扱う。
//

import SwiftUI

struct AppEntryView: View {
    @State private var cheersViewModel = AirCheersViewModel()
    @State private var accountViewModel = AccountViewModel()
    @State private var assetsReady = false
    @State private var showStartFlow = false
    @State private var startFlowStep: StartFlowView.Step = .welcome
    /// 一度でも本体（RootTabView）を出したか。以降のプロフィール設定はアカウント導線に戻す。
    @State private var hasPresentedMain = false

    var body: some View {
        ZStack {
            if !assetsReady {
                LaunchLoadingView()
            } else if showStartFlow {
                StartFlowView(
                    accountViewModel: accountViewModel,
                    initialStep: startFlowStep
                ) {
                    showStartFlow = false
                    startFlowStep = .welcome
                }
            } else if accountViewModel.needsProfileSetup && !hasPresentedMain {
                // 初回スタート直後のサインインのみ
                ProfileSetupView(
                    viewModel: accountViewModel,
                    onFinished: {
                        hasPresentedMain = true
                    },
                    onCancelled: {
                        startFlowStep = .auth
                        showStartFlow = true
                    }
                )
            } else {
                RootTabView(
                    cheersViewModel: cheersViewModel,
                    accountViewModel: accountViewModel
                )
                .onAppear {
                    hasPresentedMain = true
                }
            }
        }
        .onOpenURL { url in
            _ = accountViewModel.handleIncomingAuthURL(url)
        }
        .task {
            accountViewModel.startObservingAuthState()
            await MainActor.run {
                cheersViewModel.ensureWatchConnectivity()
            }
            let buds = await Task.detached { BeerFoamBudFactory.makeBuds() }.value
            await MainActor.run {
                cheersViewModel.seedFoamBudPool(buds)
                // 起動時すでに本体相当（スタート済み）なら、以降はアカウント導線側
                if StartFlowStore.hasCompleted || AccountAuthService.currentUser != nil {
                    hasPresentedMain = true
                }
                showStartFlow = shouldPresentStartFlow()
                assetsReady = true
            }
        }
    }

    private func shouldPresentStartFlow() -> Bool {
        if AccountAuthService.currentUser != nil {
            StartFlowStore.markCompleted()
            return false
        }
        return !StartFlowStore.hasCompleted
    }
}

#Preview {
    AppEntryView()
}


