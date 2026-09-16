//
//  WatchCheersViewModel.swift
//  beer_cheers Watch App
//
//  Watch 上の乾杯演出と、iPhone への通知を担当する。
//

import Foundation
import Observation
import SwiftUI
import WatchKit

@MainActor
@Observable
final class WatchCheersViewModel {
    private(set) var mugScale: CGFloat = 1
    private(set) var mugRotation: Double = 0
    private(set) var mugOffsetY: CGFloat = 0
    private(set) var captionVisible = false

    private var isAnimating = false

    init() {
        CheersWatchConnectivity.shared.activate()
    }

    func cheers() {
        guard !isAnimating else { return }
        isAnimating = true

        WKInterfaceDevice.current().play(.success)
        CheersWatchConnectivity.shared.sendCheers()

        captionVisible = true
        withAnimation(.interpolatingSpring(stiffness: 380, damping: 14)) {
            mugScale = 1.22
            mugRotation = 18
            mugOffsetY = -10
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 16)) {
                mugScale = 0.96
                mugRotation = -10
                mugOffsetY = 4
            }

            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 18)) {
                mugScale = 1
                mugRotation = 0
                mugOffsetY = 0
            }

            try? await Task.sleep(for: .milliseconds(450))
            captionVisible = false
            isAnimating = false
        }
    }
}
