//
//  GlassCardBackground.swift
//  beer_cheers
//
//  アカウント画面の各セクションで使う共通カード背景。
//  ・iOS 26 以降は SwiftUI 標準の Liquid Glass を `.glassEffect()` で適用
//  ・それより前の OS では Material（ultraThinMaterial）でフォールバック
//

import SwiftUI

struct GlassCardBackground: View {
    var cornerRadius: CGFloat = 20

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Group {
            if #available(iOS 26.0, *) {
                shape
                    .fill(.clear)
                    .glassEffect(.regular, in: shape)
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .overlay(
                        shape.stroke(.white.opacity(0.18), lineWidth: 1)
                    )
            }
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        GlassCardBackground()
            .frame(width: 280, height: 120)
    }
}
