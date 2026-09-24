//
//  SocialAuthButtons.swift
//  beer_cheers
//
//  Sign in with Apple / Google の共通ボタン群。
//  Apple は nonce 付き Firebase 連携のため、システムボタン見た目のカスタム実装を使う。
//

import SwiftUI

struct SocialAuthButtons: View {
    var isLoading: Bool
    var onApple: () -> Void
    var onGoogle: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: {
                guard !isLoading else { return }
                onApple()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    Text("Apple で続ける")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .foregroundStyle(.black)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1)

            Button(action: {
                guard !isLoading else { return }
                onGoogle()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "g.circle.fill")
                        .font(.title3)
                    Text("Google で続ける")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 48)
                .foregroundStyle(.black)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .disabled(isLoading)
            .opacity(isLoading ? 0.6 : 1)

            if isLoading {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.black.opacity(0.75))
                        .frame(maxWidth: .infinity)
                        .frame(height: 6)
                        .scaleEffect(x: 1, y: 1.4, anchor: .center)
                    Text("サインイン中…")
                        .font(.caption)
                        .foregroundStyle(.black.opacity(0.62))
                }
                .padding(.top, 4)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("サインイン中")
            }
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        SocialAuthButtons(isLoading: false, onApple: {}, onGoogle: {})
            .padding()
    }
}
