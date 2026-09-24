//
//  AboutSection.swift
//  beer_cheers
//
//  アプリ情報（バージョンのみ）。
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
            SectionTitle(text: "アプリ", systemImage: "info.circle")
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
        AboutSection()
            .padding()
    }
}
