//
//  TabContentLayout.swift
//  beer_cheers
//
//  浮遊タブバー下までコンテンツを伸ばすときの共通余白。
//

import SwiftUI

enum TabContentLayout {
    /// 浮遊タブバー + ホームインジケータ分（スクロール末尾・フッター用の概算）
    static let floatingTabBarClearance: CGFloat = 88
}

extension View {
    /// タブバー領域のコンテナ safe area を無視し、背景などを画面下端まで伸ばす。
    func extendsUnderFloatingTabBar() -> some View {
        ignoresSafeArea(.container, edges: .bottom)
    }
}
