//
//  AboutSection.swift
//  beer_cheers
//
//  アプリ情報（バージョン・ビルド・著作権）の表示。
//

import SwiftUI

struct AboutSection: View {
    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "アプリ情報", systemImage: "info.circle")

            HStack {
                Text("バージョン")
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(versionString)
                    .foregroundStyle(.white)
                    .font(.subheadline.monospacedDigit())
            }

            HStack {
                Text("リポジトリ")
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Link(destination: URL(string: "https://github.com/mn329/beer_cheers")!) {
                    Text("github.com/mn329/beer_cheers")
                        .font(.subheadline)
                        .underline()
                }
                .tint(.white)
            }

            Text("© beer_cheers")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 6)
        }
        .padding(16)
        .background(GlassCardBackground())
    }
}

#Preview {
    ZStack {
        AppBackground()
        AboutSection()
            .padding()
    }
}
