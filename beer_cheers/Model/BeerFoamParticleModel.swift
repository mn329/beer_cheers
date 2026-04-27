//
//  BeerFoamParticleModel.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/04/26.
//

import CoreGraphics

// MARK: - 泡粒子（ドメインモデル）

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
