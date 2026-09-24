//
//  InviteLinkConfig.swift
//  beer_cheers
//
//  ルーム招待 URL（Hosting / カスタムスキーム）のホスト設定。
//  Firebase Hosting のドメインを変えたらここも合わせる。
//

import Foundation

enum InviteLinkConfig {
    /// Firebase Hosting（またはカスタム）のホスト名。Associated Domains と一致させる。
    static let hostingHost = "beercheers.web.app"

    static let customScheme = "beercheers"

    /// Universal Link のパス先頭（`/join/{roomID}`）。
    static let joinPathPrefix = "join"

    static var httpsOrigin: URL {
        // ホストはコード定数のため失敗しない想定。万一壊れていればフォールバック。
        URL(string: "https://\(hostingHost)") ?? URL(fileURLWithPath: "/")
    }
}
