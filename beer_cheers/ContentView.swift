//
//  ContentView.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/04/26.
//

import AVFoundation
import CoreMotion
import Observation
import SwiftUI
import UIKit

// MARK: - ViewModel（CoreMotion・音声・ハプティクス）

@MainActor
@Observable
final class AirCheersViewModel {
    /// userAcceleration の合成ベクトルがこの値（G）を超えたら乾杯とみなす
    private let impactThresholdG: Double = 2.75

    /// 連続検知を防ぐクールダウン（秒）
    private let impactCooldown: TimeInterval = 0.85

    private let motionManager = CMMotionManager()
    private let motionDeliveryQueue = OperationQueue.main

    private let hapticsHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let hapticsSoft = UIImpactFeedbackGenerator(style: .soft)
    private let hapticsLight = UIImpactFeedbackGenerator(style: .light)

    private var clinkPlayer: AVAudioPlayer?
    private var didConfigureAudioSession = false

    private var lastImpactUptime: TimeInterval = 0

    /// 画面用：乾杯オーバーレイ表示
    private(set) var showKampaiBanner = false

    /// ジョッキ：跳ね・スケール・傾き（過剰リアクション用）
    private(set) var mugOffsetY: CGFloat = 0
    private(set) var mugScale: CGFloat = 1
    private(set) var mugRotationDegrees: Double = 0

    /// Canvas 泡：同一フレームで birth と ID を揃える
    private(set) var foamBurstID = UUID()
    private(set) var foamBirthdate = Date()

    private(set) var isMotionAvailable = false

    private var hideBannerTask: Task<Void, Never>?
    private var fizzHapticTask: Task<Void, Never>?

    init() {
        hapticsHeavy.prepare()
        hapticsSoft.prepare()
        hapticsLight.prepare()
        isMotionAvailable = motionManager.isDeviceMotionAvailable
        prepareClinkAudio()
    }

    private func prepareClinkAudio() {
        guard let url = Bundle.main.url(forResource: "clink", withExtension: "mp3") else { return }
        do {
            clinkPlayer = try AVAudioPlayer(contentsOf: url)
            clinkPlayer?.numberOfLoops = 0
            clinkPlayer?.prepareToPlay()
        } catch {
            clinkPlayer = nil
        }
    }

    private func ensureAudioSession() {
        guard !didConfigureAudioSession else { return }
        didConfigureAudioSession = true
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            // 再生のみ失敗してもアプリは継続
        }
    }

    private func playClinkSound() {
        ensureAudioSession()
        guard let player = clinkPlayer else { return }
        player.currentTime = 0
        player.play()
    }

    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: motionDeliveryQueue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let ua = motion.userAcceleration
            let magnitude = sqrt(ua.x * ua.x + ua.y * ua.y + ua.z * ua.z)
            guard magnitude >= self.impactThresholdG else { return }
            self.evaluateImpact(magnitude: magnitude)
        }
    }

    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        hideBannerTask?.cancel()
        hideBannerTask = nil
        fizzHapticTask?.cancel()
        fizzHapticTask = nil
    }

    private func evaluateImpact(magnitude: Double) {
        guard magnitude >= impactThresholdG else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastImpactUptime >= impactCooldown else { return }
        lastImpactUptime = now
        triggerCheers()
    }

    private func playFizzHaptics() {
        fizzHapticTask?.cancel()
        hapticsSoft.prepare()
        hapticsLight.prepare()
        fizzHapticTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(95))
            for i in 0..<8 {
                guard !Task.isCancelled else { return }
                if i.isMultiple(of: 2) {
                    hapticsSoft.impactOccurred(intensity: Double.random(in: 0.38...0.72))
                } else {
                    hapticsLight.impactOccurred(intensity: Double.random(in: 0.32...0.58))
                }
                try? await Task.sleep(for: .milliseconds(52 + i * 6))
            }
        }
    }

    private func triggerCheers() {
        playClinkSound()

        hapticsHeavy.prepare()
        hapticsHeavy.impactOccurred(intensity: 1.0)
        playFizzHaptics()

        foamBurstID = UUID()
        foamBirthdate = Date()

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

        showKampaiBanner = true
        hideBannerTask?.cancel()
        hideBannerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.38)) {
                self.showKampaiBanner = false
            }
        }
    }
}

// MARK: - Canvas 泡（サイン波で左右に揺れる）

private struct FoamBud: Sendable {
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

private struct BeerFoamCanvasView: View {
    let burstID: UUID
    let birth: Date
    private let buds: [FoamBud]

    init(burstID: UUID, birth: Date) {
        self.burstID = burstID
        self.birth = birth
        var list: [FoamBud] = []
        list.reserveCapacity(160)
        for _ in 0..<160 {
            list.append(
                FoamBud(
                    anchorXFactor: CGFloat.random(in: -0.34...0.34),
                    radius: CGFloat.random(in: 3.5...18),
                    riseSpeed: CGFloat.random(in: 220...520),
                    wobbleOmega: Double.random(in: 5.5...14.5),
                    wobbleAmplitude: CGFloat.random(in: 10...52),
                    phase: Double.random(in: 0...(2 * .pi)),
                    startDelay: Double.random(in: 0...0.22),
                    isWhiteHeavy: Double.random(in: 0...1) > 0.42,
                    lifeSpan: Double.random(in: 1.55...2.45)
                )
            )
        }
        self.buds = list
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(birth)
            Canvas { context, size in
                let centerX = size.width * 0.5
                let startY = size.height * 0.56

                for bud in buds {
                    let localT = elapsed - bud.startDelay
                    guard localT > 0 else { continue }

                    let t = localT
                    let travel = CGFloat(t) * bud.riseSpeed
                    let y = startY - travel

                    let wobbleX = CGFloat(sin(bud.wobbleOmega * t + bud.phase)) * bud.wobbleAmplitude
                    let x = centerX + size.width * bud.anchorXFactor * 0.85 + wobbleX

                    let topFadeStart = size.height * 0.12
                    let verticalAlpha: CGFloat
                    if y <= topFadeStart {
                        verticalAlpha = max(0, y / max(topFadeStart, 1))
                    } else {
                        verticalAlpha = 1
                    }

                    let lifeProgress = min(1, t / bud.lifeSpan)
                    let timeAlpha = CGFloat(max(0, 1 - pow(lifeProgress, 1.15)))
                    let alpha = max(0, min(1, timeAlpha * verticalAlpha))

                    guard alpha > 0.02, y > -bud.radius * 2, x.isFinite, y.isFinite else { continue }

                    let base = bud.isWhiteHeavy
                        ? Color.white.opacity(0.88)
                        : Color(red: 1, green: 0.92, blue: 0.35).opacity(0.9)
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

// MARK: - メイン画面

struct ContentView: View {
    @State private var viewModel = AirCheersViewModel()

    var body: some View {
        ZStack {
            backgroundLayer

            BeerFoamCanvasView(burstID: viewModel.foamBurstID, birth: viewModel.foamBirthdate)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 20) {
                Text("右手にスマホ・左手のひらに")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.95))
                Text("ガツンッ！！！")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, Color.orange.opacity(0.95)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 2)

                Spacer(minLength: 0)

                Text("🍺")
                    .font(.system(size: 168))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 10)
                    .scaleEffect(viewModel.mugScale)
                    .offset(y: viewModel.mugOffsetY)
                    .rotationEffect(.degrees(viewModel.mugRotationDegrees), anchor: .bottom)

                Spacer(minLength: 0)

                sensorStatusFooter
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 28)
            .padding(.bottom, 28)
        }
        .overlay(alignment: .center) {
            if viewModel.showKampaiBanner {
                kampaiOverlay
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.15).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .animation(.interpolatingSpring(stiffness: 260, damping: 20), value: viewModel.showKampaiBanner)
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
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

    private var kampaiOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.yellow, .orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 6
                        )
                }
                .shadow(color: .black.opacity(0.4), radius: 24, y: 14)

            VStack(spacing: 8) {
                Text("カンパーイ！！！🍻")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.45)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .red.opacity(0.92)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("（脳汁シャンパンタワー級）")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 30)
        }
        .padding(.horizontal, 18)
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
    ContentView()
}
