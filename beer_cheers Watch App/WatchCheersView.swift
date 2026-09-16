//
//  WatchCheersView.swift
//  beer_cheers Watch App
//
//  タップで乾杯エフェクトのみ。ルーム操作は iPhone 側。
//

import SwiftUI

struct WatchCheersView: View {
    @State private var viewModel = WatchCheersViewModel()

    var body: some View {
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

            VStack(spacing: 10) {
                Text("🍺")
                    .font(.system(size: 54))
                    .scaleEffect(viewModel.mugScale)
                    .rotationEffect(.degrees(viewModel.mugRotation))
                    .offset(y: viewModel.mugOffsetY)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 3)

                Text(viewModel.captionVisible ? "CHEERS!!" : "タップで乾杯")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .opacity(viewModel.captionVisible ? 1 : 0.85)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                viewModel.cheers()
            }
        }
    }
}

#Preview {
    WatchCheersView()
}
