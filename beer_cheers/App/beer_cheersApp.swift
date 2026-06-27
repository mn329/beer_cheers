//
//  beer_cheersApp.swift
//  beer_cheers
//
//  アプリのエントリポイント。Firebase の初期化のみを担当し、
//  実際の画面構築は AppEntryView → RootTabView に委ねる。
//

import SwiftUI
import UIKit
import FirebaseCore
import GoogleSignIn

@main
struct beer_cheersApp: App {
    init() {
        UserDefaults.standard.register(defaults: ["UseFloatingTabBar": true])
        configureTransparentTabBar()
        FirebaseBootstrap.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
        }
    }

    private func configureTransparentTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        appearance.backgroundEffect = nil
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
