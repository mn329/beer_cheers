//
//  SectionTitle.swift
//  beer_cheers
//
//  Liquid Glass カード内で使う統一スタイルのセクションタイトル。
//

import SwiftUI

struct SectionTitle: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(.white.opacity(0.9))
            Text(text)
                .font(.headline)
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
    }
}

struct GlassFieldBackground: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(Color.black.opacity(0.35))
            Group {
                if #available(iOS 26.0, *) {
                    shape
                        .fill(.clear)
                        .glassEffect(.regular, in: shape)
                } else {
                    shape
                        .fill(.white.opacity(0.14))
                        .overlay(
                            shape.stroke(.white.opacity(0.28), lineWidth: 1)
                        )
                }
            }
        }
    }
}
