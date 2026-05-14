//
//  CheersHapticsPlayer.swift
//  beer_cheers
//
//  乾杯のハプティクス（衝撃 + シュワ音）を担当する。
//  ・heavy 衝撃（ジョッキ衝突）
//  ・soft / light の連続 impact（炭酸のシュワ感）
//

import UIKit

@MainActor
final class CheersHapticsPlayer {
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let light = UIImpactFeedbackGenerator(style: .light)

    private var fizzTask: Task<Void, Never>?

    init() {
        heavy.prepare()
        soft.prepare()
        light.prepare()
    }

    /// 衝撃時の生成器ウォームアップ（モーション監視開始時に呼ぶ）
    func prepare() {
        heavy.prepare()
        soft.prepare()
        light.prepare()
    }

    /// 乾杯ヒット時のハプティクス。直後に細かい「シュワ」系を非同期で重ねる。
    func playImpact() {
        heavy.prepare()
        heavy.impactOccurred(intensity: 1.0)
        playFizzSequence()
    }

    /// 進行中のシュワ列を含むタスクをキャンセル
    func cancelOngoing() {
        fizzTask?.cancel()
        fizzTask = nil
    }

    private func playFizzSequence() {
        fizzTask?.cancel()
        soft.prepare()
        light.prepare()
        fizzTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(95))
            for i in 0..<8 {
                guard !Task.isCancelled else { return }
                if i.isMultiple(of: 2) {
                    soft.impactOccurred(intensity: Double.random(in: 0.38...0.72))
                } else {
                    light.impactOccurred(intensity: Double.random(in: 0.32...0.58))
                }
                try? await Task.sleep(for: .milliseconds(52 + i * 6))
            }
        }
    }
}
