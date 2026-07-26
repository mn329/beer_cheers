//
//  CheersEffectsController.swift
//  beer_cheers
//
//  乾杯時の視覚演出（ジョッキ・泡・キャプション）を担当する。
//  音・ハプティクス・リモート同期は含まない。
//

import Observation
import SwiftUI

@MainActor
@Observable
final class CheersEffectsController {
    // MARK: - Public state (View からの観測対象)

    private(set) var mugOffsetY: CGFloat = 0
    private(set) var mugScale: CGFloat = 1
    private(set) var mugRotationDegrees: Double = 0

    private(set) var foamBurstID = UUID()
    private(set) var foamBirthdate = Date()
    private(set) var foamBuds: [FoamBud] = []

    private(set) var cheersCaptionOpacity: Double = 0

    // MARK: - Timing / pool

    private let cheersCaptionHold: Duration = .milliseconds(620)
    private let cheersCaptionFade: TimeInterval = 0.26
    private var cheersCaptionHideTask: Task<Void, Never>?

    private var foamBudPool: [FoamBud]?
    private var foamPoolRefillTask: Task<Void, Never>?

    // MARK: - API

    /// 起動直後にバックグラウンドで生成した粒子を渡す（`AppEntryView` から）
    func seedFoamBudPool(_ buds: [FoamBud]) {
        if foamBudPool == nil {
            foamBudPool = buds
        }
    }

    /// 泡・キャプション・ジョッキを一度に発火する
    func playBurst() {
        foamBuds = consumeFoamBudsForBurst()
        foamBurstID = UUID()
        foamBirthdate = Date()
        flashCheersCaption()
        animateMugReaction()
    }

    /// 監視停止時など、進行中の演出タスクを止めてキャプションを消す
    func reset() {
        foamPoolRefillTask?.cancel()
        foamPoolRefillTask = nil
        cheersCaptionHideTask?.cancel()
        cheersCaptionHideTask = nil
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) {
            cheersCaptionOpacity = 0
        }
    }

    // MARK: - Mug animation

    private func animateMugReaction() {
        let kickTilt = Double.random(in: 26...38) * (Bool.random() ? 1 : -1)
        let midTilt = -kickTilt * 0.45

        withAnimation(.interpolatingSpring(stiffness: 420, damping: 14)) {
            mugOffsetY = -118
            mugScale = 1.22
            mugRotationDegrees = kickTilt
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(.interpolatingSpring(stiffness: 280, damping: 13)) {
                self.mugOffsetY = 28
                self.mugScale = 0.94
                self.mugRotationDegrees = midTilt
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
            withAnimation(.interpolatingSpring(stiffness: 210, damping: 17)) {
                self.mugOffsetY = -10
                self.mugScale = 1.05
                self.mugRotationDegrees = kickTilt * 0.35
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.interpolatingSpring(stiffness: 180, damping: 22)) {
                self.mugOffsetY = 0
                self.mugScale = 1
                self.mugRotationDegrees = 0
            }
        }
    }

    // MARK: - Caption

    private func flashCheersCaption() {
        cheersCaptionHideTask?.cancel()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            cheersCaptionOpacity = 1
        }
        cheersCaptionHideTask = Task { @MainActor in
            try? await Task.sleep(for: self.cheersCaptionHold)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: self.cheersCaptionFade)) {
                self.cheersCaptionOpacity = 0
            }
        }
    }

    // MARK: - Foam pool

    private func consumeFoamBudsForBurst() -> [FoamBud] {
        let pack: [FoamBud]
        if let pooled = foamBudPool {
            foamBudPool = nil
            pack = pooled
        } else {
            pack = BeerFoamBudFactory.makeBuds()
        }
        scheduleFoamBudPoolRefill()
        return pack
    }

    private func scheduleFoamBudPoolRefill() {
        foamPoolRefillTask?.cancel()
        foamPoolRefillTask = Task { @MainActor in
            let next = await Task.detached { BeerFoamBudFactory.makeBuds() }.value
            guard !Task.isCancelled else { return }
            if foamBudPool == nil {
                foamBudPool = next
            }
        }
    }
}
