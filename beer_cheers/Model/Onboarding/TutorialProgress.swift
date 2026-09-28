//
//  TutorialProgress.swift
//  beer_cheers
//
//  使い方ガイドの進行状態（どのステップか・練習乾杯できたか）。
//  タブ切替や保存などの副作用は持たず、RootTabView がこの状態を見て反映する。
//

import Foundation

struct TutorialProgress {
    private(set) var step: TutorialStep?
    private(set) var didPracticeCheers = false

    var isActive: Bool { step != nil }

    mutating func start() {
        step = .cheers
        didPracticeCheers = false
    }

    /// 最後のステップで呼ぶと終了（`isActive == false`）になる。
    mutating func advance() {
        step = step?.next
    }

    mutating func finish() {
        step = nil
    }

    /// 乾杯ステップ中の乾杯だけを練習として数える。
    mutating func recordLocalCheers() {
        guard step == .cheers else { return }
        didPracticeCheers = true
    }
}
