//
//  CheersView.swift
//  beer_cheers
//
//  乾杯のメイン画面。背景・ジョッキ・泡 Canvas・センサ状態の表示と、
//  AirCheersViewModel のモーション監視ライフサイクル（start/stop）を担当する。
//  Firebase リモート乾杯の監視は RootTabView で行う（タブ切替で途切れないようにするため）。
//

import SwiftUI

// MARK: - レイアウト定数

private enum BeerLayout {
    /// 画面高さに対するジョッキ中心の Y 位置（0 = 上端、1 = 下端）。泡の `foamOriginYFactor` と同一にする。
    static let beerCenterYFactor: CGFloat = 0.56
    static let beerEmojiSize: CGFloat = 168
    static let footerBottomPadding: CGFloat = 28
    static let cheersCaptionTopPadding: CGFloat = 50
}

struct CheersView: View {
    @Bindable var viewModel: AirCheersViewModel

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let beerCenterY = h * BeerLayout.beerCenterYFactor

            ZStack {
                AppBackground()

                BeerFoamCanvasView(
                    burstID: viewModel.effects.foamBurstID,
                    birth: viewModel.effects.foamBirthdate,
                    foamOriginYFactor: BeerLayout.beerCenterYFactor,
                    buds: viewModel.effects.foamBuds
                )
                .frame(width: w, height: h)
                .allowsHitTesting(false)

                beerMug
                    .position(x: w * 0.5, y: beerCenterY)

                VStack {
                    Spacer(minLength: 0)
                    sensorStatusFooter
                }
                .frame(width: w, height: h)
                .padding(
                    .bottom,
                    BeerLayout.footerBottomPadding + TabContentLayout.floatingTabBarClearance
                )

                cheersCaptionOverlay
            }
            .frame(width: w, height: h)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
    }

    private var beerMug: some View {
        Text("🍺")
            .font(.system(size: BeerLayout.beerEmojiSize))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 10)
            .scaleEffect(viewModel.effects.mugScale)
            .rotationEffect(.degrees(viewModel.effects.mugRotationDegrees), anchor: .bottom)
            .offset(y: viewModel.effects.mugOffsetY)
    }

    private var cheersCaptionOverlay: some View {
        VStack {
            Text("CHEERS!!")
                .font(.system(size: 40, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.55), radius: 0, y: 1)
                .shadow(color: .black.opacity(0.4), radius: 14, y: 5)
                .opacity(viewModel.effects.cheersCaptionOpacity)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.28 * viewModel.effects.cheersCaptionOpacity))
                )
                .padding(.top, BeerLayout.cheersCaptionTopPadding)
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
        .padding()
    }
}

#Preview {
    CheersView(viewModel: AirCheersViewModel())
}
