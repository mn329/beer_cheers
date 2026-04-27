//
//  ContentView.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/04/26.
//

import SwiftUI

// MARK: - メイン画面

private enum BeerLayout {
    /// 画面高さに対するジョッキ中心の Y 位置（0 = 上端、1 = 下端）。泡の `foamOriginYFactor` と同一にする。
    static let beerCenterYFactor: CGFloat = 0.56
}

struct ContentView: View {
    @Bindable var viewModel: AirCheersViewModel

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let beerCenterY = h * BeerLayout.beerCenterYFactor

            ZStack {
                backgroundLayer

                BeerFoamCanvasView(
                    burstID: viewModel.foamBurstID,
                    birth: viewModel.foamBirthdate,
                    foamOriginYFactor: BeerLayout.beerCenterYFactor,
                    buds: viewModel.foamBuds
                )
                .frame(width: w, height: h)
                .allowsHitTesting(false)

                Text("🍺")
                    .font(.system(size: 168))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 10)
                    .scaleEffect(viewModel.mugScale)
                    .rotationEffect(.degrees(viewModel.mugRotationDegrees), anchor: .bottom)
                    .offset(y: viewModel.mugOffsetY)
                    .position(x: w * 0.5, y: beerCenterY)

                VStack {
                    Spacer(minLength: 0)
                    sensorStatusFooter
                }
                .frame(width: w, height: h)
                .padding(.bottom, 28)

                cheersCaptionOverlay
            }
            .frame(width: w, height: h)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.startMonitoring()
            DispatchQueue.main.async {
                viewModel.startRemoteTriggerListening()
            }
        }
        .onDisappear {
            viewModel.stopMonitoring()
            viewModel.stopRemoteTriggerListening()
        }
    }

    private var backgroundLayer: some View {
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
            RadialGradient(
                colors: [.white.opacity(0.28), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }

    private var cheersCaptionOverlay: some View {
        VStack {
            Text("CHEERS!!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 0, y: 1)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 5)
                .opacity(viewModel.cheersCaptionOpacity)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.28 * viewModel.cheersCaptionOpacity))
                )
                .padding(.top, 50)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var sensorStatusFooter: some View {
        Group {
            if viewModel.isMotionAvailable {
                Label("センサー監視中・全力でぶつけろ！", systemImage: "sensor.tag.radiowaves.forward.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            } else {
                Text("この端末では Device Motion が使えません 🥲")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView(viewModel: AirCheersViewModel())
}
