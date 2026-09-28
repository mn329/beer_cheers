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
    /// 上端のルームバッジと重ならない位置。
    static let cheersCaptionTopPadding: CGFloat = 72
    static let roomBadgeTopPadding: CGFloat = 8
}

struct CheersView: View {
    @Bindable var viewModel: AirCheersViewModel
    var roomStatus = CheersRoomStatus(roomID: RoomSessionStore.makeGuestRoomID(), memberCount: nil)
    /// 直近の乾杯を送ってきた相手のニックネーム。自分の乾杯や不明な相手なら nil。
    var senderName: String?
    var onOpenRoom: () -> Void = {}

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
                    buds: viewModel.effects.foamBuds,
                    isAnimating: viewModel.effects.isFoamAnimating
                )
                .frame(width: w, height: h)
                .allowsHitTesting(false)

                beerMug
                    .position(x: w * 0.5, y: beerCenterY)

                VStack {
                    Spacer(minLength: 0)
                    sensorStatusFooter
                        .padding(
                            .bottom,
                            BeerLayout.footerBottomPadding + TabContentLayout.floatingTabBarClearance
                        )
                }
                .frame(width: w, height: h)

                VStack {
                    roomBadge
                        .padding(.top, BeerLayout.roomBadgeTopPadding)
                    Spacer(minLength: 0)
                }
                .frame(width: w, height: h)

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

    private var roomBadge: some View {
        Button(action: onOpenRoom) {
            HStack(spacing: 8) {
                Image(systemName: roomStatus.isAlone ? "person.fill" : "person.2.fill")
                    .font(.footnote)
                VStack(alignment: .leading, spacing: 1) {
                    Text(roomStatus.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let subtitle = roomStatus.subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule(style: .continuous).fill(Color.black.opacity(0.28)))
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
        .accessibilityHint("ルームタブを開く")
    }

    private var cheersCaptionOverlay: some View {
        VStack(spacing: 10) {
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
            if let senderName {
                Text(CheersRoomStatus.senderCaption(nickname: senderName))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
                    .opacity(viewModel.effects.cheersCaptionOpacity)
                    .padding(.horizontal, 24)
            }
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
