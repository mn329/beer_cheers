//
//  StartFlowView.swift
//  beer_cheers
//
//  初回スタート: ようこそ → Apple / Google / ゲスト。
//

import SwiftUI

struct StartFlowView: View {
    @Bindable var accountViewModel: AccountViewModel
    var initialStep: Step = .welcome
    var onFinished: () -> Void

    @State private var step: Step = .welcome

    enum Step: Equatable {
        case welcome
        case auth
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 24)

                switch step {
                case .welcome:
                    welcomeContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                case .auth:
                    authContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 24)
            .animation(.easeInOut(duration: 0.28), value: step)
        }
        .onAppear {
            step = initialStep
        }
    }

    // MARK: - Welcome（白文字のまま）

    private var welcomeContent: some View {
        VStack(spacing: 28) {
            Text("🍺")
                .font(.system(size: 72))

            VStack(spacing: 10) {
                Text("beer cheers")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("離れた仲間と、振る乾杯を共有しよう。\nZoom の横に置くだけで、音と振動が届く。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                step = .auth
            } label: {
                Text("はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.95))
            .foregroundStyle(.black)
        }
    }

    // MARK: - Auth（文字は黒で統一。ゲストは目立たせない）

    private var authContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("アカウント")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.black)

                Text("Apple または Google でサインインしてください。")
                    .font(.subheadline)
                    .foregroundStyle(.black.opacity(0.72))
            }

            SocialAuthButtons(
                isLoading: accountViewModel.isAuthLoading,
                onApple: { Task { await signInApple() } },
                onGoogle: { Task { await signInGoogle() } }
            )

            if let message = accountViewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.error)
            }

            Button {
                step = .welcome
            } label: {
                Text("戻る")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.black.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }
            .disabled(accountViewModel.isAuthLoading)
            .padding(.top, 4)

            // ゲスト: 小さいテキストリンク（文言はわかりやすく）
            Button {
                finishAsGuest()
            } label: {
                Text("ゲストで始める")
                    .font(.caption2)
                    .foregroundStyle(.black.opacity(0.28))
                    .underline()
                    .frame(maxWidth: .infinity)
            }
            .disabled(accountViewModel.isAuthLoading)
            .padding(.top, 8)
            .accessibilityLabel("ゲストで始める")
        }
        .padding(20)
        .background(GlassCardBackground())
    }

    // MARK: - Actions

    private func signInApple() async {
        let ok = await accountViewModel.signInWithApple()
        if ok { finish() }
    }

    private func signInGoogle() async {
        let ok = await accountViewModel.signInWithGoogle()
        if ok { finish() }
    }

    private func finishAsGuest() {
        finish()
    }

    private func finish() {
        StartFlowStore.markCompleted()
        onFinished()
    }
}

#Preview {
    StartFlowView(accountViewModel: AccountViewModel(), initialStep: .welcome, onFinished: {})
}
