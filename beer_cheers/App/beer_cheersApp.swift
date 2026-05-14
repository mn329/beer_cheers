//
//  beer_cheersApp.swift
//  beer_cheers
//
//  アプリのエントリポイント。Firebase の初期化のみを担当し、
//  実際の画面構築は AppEntryView → RootTabView に委ねる。
//

import SwiftUI

@main
struct beer_cheersApp: App {
    init() {
        FirebaseBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
        }
    }
}
