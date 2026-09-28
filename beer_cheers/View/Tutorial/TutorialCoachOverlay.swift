//
//  TutorialCoachOverlay.swift
//  beer_cheers
//
//  本体（RootTabView）の上に重ねる使い方ガイド（乾杯 → Apple Watch → ルーム）。
//  タブ切替・練習乾杯の検知・完了フラグの保存は RootTabView、文言は TutorialStep が担当する。
//

import SwiftUI

struct TutorialCoachOverlay: View {
    let step: TutorialStep
    let isMotionAvailable: Bool
    let didPracticeCheers: Bool
    var onNext: () -> Void
    var onSkip: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            // 説明中は下の画面やタブバーを操作させない（振る操作はタッチ不要）
            Rectangle()
                .fill(Color.black.opacity(dimOpacity))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {}
                .accessibilityHidden(true)

            coachCard
                .id(step)
                .transition(.opacity)
                .frame(maxHeight: .infinity, alignment: cardAlignment)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .animation(.easeInOut(duration: 0.25), value: didPracticeCheers)
    }

    /// 説明対象（ジョッキ／ルームの入力欄）を隠さない位置に置く。
    private var cardAlignment: Alignment {
        switch step {
        case .cheers: .bottom
        case .watch: .center
        case .room: .top
        }
    }

    private var dimOpacity: Double {
        switch step {
        case .cheers: 0
        case .watch: 0.45
        case .room: 0.2
        }
    }

    private var isWaitingForPractice: Bool {
        step == .cheers
            && TutorialStep.isWaitingForPractice(isMotionAvailable: isMotionAvailable, didPracticeCheers: didPracticeCheers)
    }

    // MARK: - Card

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            // 小さい画面や大きい文字サイズでは本文だけスクロールさせ、ボタンは常に見せる
            ViewThatFits(in: .vertical) {
                stepBody
                ScrollView {
                    stepBody
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            actions
        }
        .padding(18)
        .background(cardBackground)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// 下の画面のガラスカードと重なっても読めるよう、ガラスではなく不透明に近い面にする。
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return shape
            .fill(Color.white.opacity(0.94))
            .overlay(shape.stroke(Color.white.opacity(0.6), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(step.emoji(didPracticeCheers: didPracticeCheers))
                .font(.system(size: 32))
                .accessibilityHidden(true)
            Text(step.title(didPracticeCheers: didPracticeCheers))
                .font(.title3.weight(.bold))
                .foregroundStyle(AccountContentStyle.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Text(step.progressText)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(AccountContentStyle.secondary)
                .accessibilityLabel("\(TutorialStep.allCases.count) ステップ中 \(step.rawValue + 1)")
        }
    }

    private var stepBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            if step == .cheers {
                Text(TutorialStep.practiceMessage(isMotionAvailable: isMotionAvailable, didPracticeCheers: didPracticeCheers))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AccountContentStyle.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(TutorialStep.practiceNote)
                    .font(.caption)
                    .foregroundStyle(AccountContentStyle.secondary)
            }

            if let screenshot = step.screenshot {
                Image(screenshot.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: dynamicTypeSize.isAccessibilitySize ? 90 : 150)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .accessibilityLabel(screenshot.accessibilityLabel)
            }

            ForEach(step.bullets, id: \.self) { bullet in
                Label {
                    Text(bullet.text)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AccountContentStyle.primary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: bullet.systemImage)
                        .foregroundStyle(AccountContentStyle.secondary)
                        .frame(width: 28)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 12) {
            if step.next != nil {
                Button("スキップ") {
                    onSkip()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AccountContentStyle.secondary)
                .accessibilityHint("使い方ガイドを終了します")
            }
            Spacer(minLength: 0)
            if isWaitingForPractice {
                Button {
                    onNext()
                } label: {
                    actionLabel("あとで試す")
                }
                .buttonStyle(.bordered)
                .tint(AccountContentStyle.primary)
            } else {
                Button {
                    onNext()
                } label: {
                    actionLabel(step.next == nil ? "はじめる" : "次へ")
                }
                .buttonStyle(.borderedProminent)
                .tint(AccountContentStyle.primary)
                .foregroundStyle(.white)
            }
        }
    }

    private func actionLabel(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
    }
}

#Preview("乾杯・練習前") {
    ZStack {
        AppBackground()
        TutorialCoachOverlay(step: .cheers, isMotionAvailable: true, didPracticeCheers: false, onNext: {}, onSkip: {})
    }
}

#Preview("乾杯・練習後") {
    ZStack {
        AppBackground()
        TutorialCoachOverlay(step: .cheers, isMotionAvailable: true, didPracticeCheers: true, onNext: {}, onSkip: {})
    }
}

#Preview("Watch・大きい文字") {
    ZStack {
        AppBackground()
        TutorialCoachOverlay(step: .watch, isMotionAvailable: true, didPracticeCheers: false, onNext: {}, onSkip: {})
    }
    .dynamicTypeSize(.accessibility2)
}
