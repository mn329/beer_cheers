//
//  AppEntryView.swift
//  beer_cheers
//
//  起動時に泡パーティクルを生成するあいだ、乾杯ループのローディングを表示してから RootTabView に切り替える。
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
                LaunchLoadingView()
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
}

#Preview {
    AppEntryView()
}
