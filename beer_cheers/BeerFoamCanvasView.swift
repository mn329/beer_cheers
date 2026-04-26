//
//  BeerFoamCanvasView.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/04/26.
//

import SwiftUI

// MARK: - Canvas 泡（サイン波で左右に揺れる）

// MARK: - 泡粒子生成（メインスレッド外でも呼べる）

enum BeerFoamBudFactory: Sendable {
    nonisolated static let bubbleCount = 200

    nonisolated static func makeBuds() -> [FoamBud] {
        var list: [FoamBud] = []
        list.reserveCapacity(Self.bubbleCount)
        for _ in 0..<Self.bubbleCount {
            list.append(
                FoamBud(
                    anchorXFactor: CGFloat.random(in: -0.42...0.42),
                    radius: CGFloat.random(in: 5...26),
                    riseSpeed: CGFloat.random(in: 180...480),
                    wobbleOmega: Double.random(in: 5.0...14.0),
                    wobbleAmplitude: CGFloat.random(in: 12...58),
                    phase: Double.random(in: 0...(2 * .pi)),
                    startDelay: Double.random(in: 0...0.18),
                    isWhiteHeavy: Double.random(in: 0...1) > 0.38,
                    lifeSpan: Double.random(in: 2.0...3.2)
                )
            )
        }
        return list
    }
}

struct FoamBud: Sendable {
    /// 画面幅に対する基準横位置（0 = 中央）
    let anchorXFactor: CGFloat
    let radius: CGFloat
    /// 上方向の速度（pt / 秒）
    let riseSpeed: CGFloat
    /// サイン波の角周波数（ラジアン/秒）
    let wobbleOmega: Double
    let wobbleAmplitude: CGFloat
    let phase: Double
    /// 噴出開始までの遅延（秒）
    let startDelay: Double
    let isWhiteHeavy: Bool
    /// 寿命（秒）— これを超えたら完全消滅
    let lifeSpan: Double
}

struct BeerFoamCanvasView: View {
    let burstID: UUID
    let birth: Date
    /// 泡の噴出基準の画面高さに対する比率（0 = 上端、1 = 下端）。ジョッキの位置に合わせる。
    let foamOriginYFactor: CGFloat
    let buds: [FoamBud]

    init(burstID: UUID, birth: Date, foamOriginYFactor: CGFloat = 0.5, buds: [FoamBud]) {
        self.burstID = burstID
        self.birth = birth
        self.foamOriginYFactor = foamOriginYFactor
        self.buds = buds
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 80.0, paused: false)) { timeline in
            // birth と timeline.date のわずかな逆転で負になると全泡が描画されないため下限を張る
            let elapsed = max(0, timeline.date.timeIntervalSince(birth))
            Canvas { context, size in
                let centerX = size.width * 0.5
                let startY = size.height * foamOriginYFactor

                for bud in buds {
                    let localT = elapsed - bud.startDelay
                    guard localT >= 0 else { continue }

                    let t = localT
                    let travel = CGFloat(t) * bud.riseSpeed
                    let y = startY - travel

                    let wobbleX = CGFloat(sin(bud.wobbleOmega * t + bud.phase)) * bud.wobbleAmplitude
                    let x = centerX + size.width * bud.anchorXFactor * 0.9 + wobbleX

                    let topFadeStart = size.height * 0.1
                    let verticalAlpha: CGFloat
                    if y <= topFadeStart {
                        verticalAlpha = max(0, y / max(topFadeStart, 1))
                    } else {
                        verticalAlpha = 1
                    }

                    let lifeProgress = min(1, t / bud.lifeSpan)
                    let timeAlpha = CGFloat(max(0, 1 - pow(lifeProgress, 1.05)))
                    let alpha = max(0, min(1, timeAlpha * verticalAlpha))

                    guard alpha > 0.03, y > -bud.radius * 2, x.isFinite, y.isFinite else { continue }

                    let base = bud.isWhiteHeavy
                        ? Color.white.opacity(0.96)
                        : Color(red: 1, green: 0.94, blue: 0.42).opacity(0.96)
                    let fillColor = base.opacity(Double(alpha))

                    let rect = CGRect(x: x - bud.radius, y: y - bud.radius, width: bud.radius * 2, height: bud.radius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(fillColor))
                }
            }
            .allowsHitTesting(false)
        }
        .id(burstID)
    }
}

