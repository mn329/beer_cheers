//
//  LaunchLoadingView.swift
//  beer_cheers
//
//  起動中のローディング。ジョッキ2つが円弧上を動いて乾杯し、同じ姿勢に戻って途切れなく繰り返す。
//  左: 円の一番下 → 右／右: 一番下 → 左。液体がこぼれないよう傾きは抑え、待機時は上向き。
//

import SwiftUI

struct LaunchLoadingView: View {
    /// 1 サイクル（下 → 衝突 → 下）の秒数。
    private let cycleDuration: TimeInterval = 1.55
    private let mugSize: CGFloat = 96
    /// 円の半径（大きいほど下から上への振り上げが広い）。
    private let arcRadius: CGFloat = 72
    /// 左右の円の中心 X。大きいほど衝突時の間隔が空く。
    private let circleCenterX: CGFloat = 102
    /// 四半円のうちどこまで進むか（1 だと左右が同じ点に重なる）。
    private let arcSweepFraction: Double = 0.62

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 28) {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
                    let phase = cyclePhase(at: context.date)
                    // 0→1→0。端が一致するのでループが途切れない（最後は必ず上向き）。
                    let progress = CGFloat(sin(phase * .pi))
                    let flash = impactFlash(progress: progress)

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(0.5 * flash),
                                        Color(red: 1.0, green: 0.9, blue: 0.55).opacity(0.22 * flash),
                                        .clear,
                                    ],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 52
                                )
                            )
                            .frame(width: 96, height: 96)
                            .offset(y: -arcRadius * CGFloat(sin(Double.pi / 2 * arcSweepFraction)) * 0.35)
                            .blur(radius: 2)
                            .allowsHitTesting(false)

                        mug(mirrored: true)
                            .modifier(
                                ArcMugModifier(
                                    progress: progress,
                                    side: .left,
                                    radius: arcRadius,
                                    circleCenterX: circleCenterX,
                                    arcSweepFraction: arcSweepFraction
                                )
                            )

                        mug(mirrored: false)
                            .modifier(
                                ArcMugModifier(
                                    progress: progress,
                                    side: .right,
                                    radius: arcRadius,
                                    circleCenterX: circleCenterX,
                                    arcSweepFraction: arcSweepFraction
                                )
                            )
                    }
                    .frame(width: 320, height: 250)
                    .shadow(color: .black.opacity(0.22 + 0.1 * flash), radius: 10, y: 8)
                }

                Text("準備中…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .accessibilityLabel("起動中")
    }

    private func mug(mirrored: Bool) -> some View {
        Text("🍺")
            .font(.system(size: mugSize))
            .scaleEffect(x: mirrored ? -1 : 1, y: 1)
    }

    /// [0, 1) の連続フェーズ。
    private func cyclePhase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
    }

    /// 衝突付近（progress ≈ 1）だけ光る。
    private func impactFlash(progress: CGFloat) -> CGFloat {
        let t = max(0, progress - 0.82) / 0.18
        return t * t
    }
}

// MARK: - Arc motion

private enum MugSide {
    case left
    case right
}

/// 数学角（右 = 0、反時計回り、Y 上向き）で円弧を定義し、SwiftUI 座標へ写す。
/// 左: 下 → 右寄り／右: 下 → 左寄り。四半円手前で止め、ジョッキ同士が重ならないようにする。
private struct ArcMugModifier: ViewModifier {
    let progress: CGFloat
    let side: MugSide
    let radius: CGFloat
    let circleCenterX: CGFloat
    let arcSweepFraction: Double

    /// こぼれない範囲の最大傾き（度）。progress=0 では必ず 0（上向き）。
    private let maxTiltDegrees: Double = 10

    func body(content: Content) -> some View {
        let angle = arcAngle(progress: progress, side: side)
        let cx: CGFloat = side == .left ? -circleCenterX : circleCenterX
        let x = cx + radius * CGFloat(cos(angle))
        let y = -radius * CGFloat(sin(angle))
        let tilt = tiltDegrees(progress: progress, side: side)

        content
            .rotationEffect(.degrees(tilt), anchor: .bottom)
            .scaleEffect(1 + 0.04 * progress)
            .offset(x: x, y: y)
    }

    private func arcAngle(progress: CGFloat, side: MugSide) -> Double {
        let p = Double(progress)
        let start = -Double.pi / 2
        let sweep = (Double.pi / 2) * arcSweepFraction
        switch side {
        case .left:
            return start + p * sweep
        case .right:
            return start - p * sweep
        }
    }

    private func tiltDegrees(progress: CGFloat, side: MugSide) -> Double {
        // 乾杯時だけわずかに内側へ。開始・終了は 0 で口が上を向く。
        let amount = Double(progress) * maxTiltDegrees
        switch side {
        case .left: return amount
        case .right: return -amount
        }
    }
}

#Preview {
    LaunchLoadingView()
}
