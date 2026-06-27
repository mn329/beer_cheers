//
//  GlassCardBackground.swift
//  beer_cheers
//
//  アカウント画面の各セクション・入力欄で使う共通ガラス背景。
//  ・薄いスクラム + Liquid Glass で透け感を出しつつ文字のコントラストを確保
//  ・iOS 26 以降は `.glassEffect()`、それ以前は Material でフォールバック
//

import SwiftUI

// MARK: - Shared glass surface

private struct GlassSurfaceBackground: View {
    let cornerRadius: CGFloat
    /// 背景グラデーション上での文字可読性用（小さいほど透明）
    var scrimOpacity: Double

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(scrimOpacity))
            shape.fill(
                LinearGradient(
                    colors: [
                        .white.opacity(0.10),
                        .white.opacity(0.02),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            if #available(iOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
            } else {
                shape
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(glassBorder(in: shape))
    }

    private func glassBorder(in shape: RoundedRectangle) -> some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    .white.opacity(0.48),
                    .white.opacity(0.16),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
    }
}

// MARK: - Section card

struct GlassCardBackground: View {
    var cornerRadius: CGFloat = 20

    var body: some View {
        GlassSurfaceBackground(cornerRadius: cornerRadius, scrimOpacity: 0.07)
    }
}

// MARK: - TextField

struct GlassFieldBackground: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        // カードと同じガラス処理。入力欄だけごくわずかにスクラムを足して境界を出す
        GlassSurfaceBackground(cornerRadius: cornerRadius, scrimOpacity: 0.25)
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: 16) {
            GlassCardBackground()
                .frame(height: 100)
            GlassFieldBackground()
                .frame(height: 44)
        }
        .padding()
    }
}
