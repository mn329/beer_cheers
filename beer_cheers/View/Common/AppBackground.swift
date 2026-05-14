//
//  AppBackground.swift
//  beer_cheers
//
//  全画面で共有するビール基調のグラデーション背景。
//

import SwiftUI

struct AppBackground: View {
    var body: some View {
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
}

#Preview {
    AppBackground()
}
