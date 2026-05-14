//
//  AppEntryView.swift
//  beer_cheers
//
//  起動時に泡パーティクルをバックグラウンドで生成してから RootTabView に切り替えるエントリ。
//

import SwiftUI

struct AppEntryView: View {
    @State private var viewModel = AirCheersViewModel()
    @State private var assetsReady = false

    var body: some View {
        ZStack {
            if assetsReady {
                RootTabView(cheersViewModel: viewModel)
            } else {
                warmupPlaceholder
            }
        }
        .task {
            // モーション監視を先に開始するとアームクロック計測が始まる
            await MainActor.run {
                viewModel.startMonitoring()
            }
            let buds = await Task.detached { BeerFoamBudFactory.makeBuds() }.value
            await MainActor.run {
                viewModel.seedFoamBudPool(buds)
                assetsReady = true
            }
        }
    }

    private var warmupPlaceholder: some View {
        ZStack {
            AppBackground()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.15)
        }
    }
}

#Preview {
    AppEntryView()
}
