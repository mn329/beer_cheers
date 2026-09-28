//
//  AboutSection.swift
//  beer_cheers
//
//  アプリ情報（使い方の再表示・バージョン）。
//

import SwiftUI

struct AboutSection: View {
    var onShowTutorial: () -> Void

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "アプリ", systemImage: "info.circle")

            Button {
                onShowTutorial()
            } label: {
                HStack {
                    Text("使い方を見る")
                        .foregroundStyle(AccountContentStyle.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AccountContentStyle.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Text("バージョン")
                    .foregroundStyle(AccountContentStyle.secondary)
                Spacer()
                Text(versionString)
                    .foregroundStyle(AccountContentStyle.primary)
                    .font(.subheadline.monospacedDigit())
            }
        }
        .padding(16)
        .background(GlassCardBackground())
    }
}

#Preview {
    ZStack {
        AppBackground()
        AboutSection(onShowTutorial: {})
            .padding()
    }
}
