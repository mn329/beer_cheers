//
//  AppEntryView.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/04/26.
//

import SwiftUI

// MARK: - 起動時：泡データをバックグラウンドで用意してから本画面へ

struct AppEntryView: View {
    @State private var viewModel = AirCheersViewModel()
    @State private var assetsReady = false

    var body: some View {
        ZStack {
            if assetsReady {
                ContentView(viewModel: viewModel)
            } else {
                warmupPlaceholder
            }
        }
        .task {
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
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.72, blue: 0.18),
                    Color(red: 0.92, green: 0.45, blue: 0.12),
                    Color(red: 0.55, green: 0.12, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.15)
        }
    }
}
