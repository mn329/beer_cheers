//
//  FirebaseBootstrap.swift
//  beer_cheers
//
//  バンドル内の Firebase 用 plist から FirebaseApp を初期化する。
//  ・GoogleService-Info.plist があれば標準の `configure()` を使う
//  ・無ければ README 手順で配置する Firebase Project Settings - beercheers.plist を読む
//  ・Realtime Database 用に plist に DATABASE_URL を含めること
//

import FirebaseCore
import Foundation

enum FirebaseBootstrap {
    static func configure() {
        let bundle = Bundle.main

        if bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            return
        }

        let beercheersPlistPath = bundle.path(
            forResource: "Firebase Project Settings - beercheers", ofType: "plist")
        if let path = beercheersPlistPath, let options = FirebaseOptions(contentsOfFile: path) {
            FirebaseApp.configure(options: options)
            return
        }

        #if DEBUG
            if beercheersPlistPath != nil {
                print(
                    "[beer_cheers] Firebase Project Settings - beercheers.plist はあるが FirebaseOptions の読み込みに失敗しました。キー名・値（特に DATABASE_URL）が Firebase コンソールと一致しているか確認してください。"
                )
            } else if bundle.path(
                forResource: "Firebase Project Settings - beercheers.plist", ofType: "example") != nil
            {
                print(
                    "[beer_cheers] `.plist.example` だけでは初期化されません。README のとおり `Firebase Project Settings - beercheers.plist` にコピーし、プレースホルダを本番の値に置き換えてください。"
                )
            } else {
                print(
                    "[beer_cheers] Firebase 用 plist が見つかりません。GoogleService-Info.plist を追加するか、README の手順で Firebase Project Settings - beercheers.plist を配置してください。"
                )
            }
        #endif
    }

    /// FirebaseApp が初期化済みか（Realtime DB 等を使う前のガードに利用）
    static var isConfigured: Bool { FirebaseApp.app() != nil }
}
