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
  /// - 無ければ README の手順で配置する `Firebase Project Settings - beercheers.plist`（`FirebaseOptions` 経由）。
  /// Realtime Database 用に plist に **`DATABASE_URL`** を含めること。
  private static func configureFirebase() {
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
}
