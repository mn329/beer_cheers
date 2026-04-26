//
//  beer_cheersApp.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/04/26.
//

import FirebaseCore
import SwiftUI

@main
struct beer_cheersApp: App {
    init() {
        Self.configureFirebase()
    }

    var body: some Scene {
        WindowGroup {
            AppEntryView()
        }
    }

    /// バンドル内の Firebase 用 plist から初期化する。
    /// - `GoogleService-Info.plist` があれば標準の `configure()`。
    /// - 無ければ同形式のカスタム名 plist を順に試す（`FirebaseOptions` 経由）。
    /// Realtime Database 用に plist に **`DATABASE_URL`** を含めること。
    private static func configureFirebase() {
        let bundle = Bundle.main

        if bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            return
        }

        let customPlistNames = [
            "Firebase App Config",
            "Firebase Project Settings - beercheers",
        ]
        for name in customPlistNames {
            guard let path = bundle.path(forResource: name, ofType: "plist"),
                  let options = FirebaseOptions(contentsOfFile: path)
            else { continue }
            FirebaseApp.configure(options: options)
            return
        }

        #if DEBUG
        print(
            "[beer_cheers] Firebase 用 plist が見つかりません。GoogleService-Info.plist を追加するか、customPlistNames に plist のファイル名（拡張子なし）を追加してください。"
        )
        #endif
    }
}

