//
//  SectionTitle.swift
//  beer_cheers
//
//  Liquid Glass カード内で使う統一スタイルのセクションタイトル。
//

import SwiftUI

/// アカウント画面の文字色（透明ガラス上で読みやすい黒系）
enum AccountContentStyle {
    static let primary = Color.black
    static let secondary = Color.black.opacity(0.62)
    static let error = Color(red: 0.55, green: 0.12, blue: 0.08)
}

struct SectionTitle: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(AccountContentStyle.secondary)
            Text(text)
                .font(.headline)
                .foregroundStyle(AccountContentStyle.primary)
            Spacer(minLength: 0)
        }
    }
}
