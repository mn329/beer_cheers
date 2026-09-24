//
//  AuthXcodeConfigValidator.swift
//  beer_cheers
//
//  DEBUG 起動時に、Xcode / Info.plist 側の認証設定をログで確認する。
//  Firebase コンソールや Apple Developer の設定はここでは検証できない。
//

import FirebaseCore
import Foundation
import GoogleSignIn

enum AuthXcodeConfigValidator {
    static func validateAndLog() {
        #if DEBUG
        var lines: [String] = ["[AuthConfig] Xcode / バンドル側の確認"]

        let bundleID = Bundle.main.bundleIdentifier ?? "(nil)"
        lines.append("- Bundle ID: \(bundleID)")
        if bundleID != "com.minato.beer-cheers" {
            lines.append("  ⚠ 想定は com.minato.beer-cheers")
        } else {
            lines.append("  ✓ Bundle ID OK")
        }

        let schemes = urlSchemes()
        let googleScheme = schemes.first { $0.hasPrefix("com.googleusercontent.apps.") }
        if let googleScheme {
            lines.append("- Google URL scheme: \(googleScheme)")
            lines.append("  ✓ Google URL Types あり")
        } else {
            lines.append("- Google URL scheme: 見つからない")
            lines.append("  ⚠ beer-cheers-Info.plist の CFBundleURLTypes を確認")
        }

        if schemes.contains("beercheers") {
            lines.append("- 招待スキーム beercheers: ✓")
        } else {
            lines.append("- 招待スキーム beercheers: ⚠ なし")
        }

        if let gid = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String, !gid.isEmpty {
            lines.append("- GIDClientID: ✓ (\(gid.prefix(24))…)")
        } else {
            lines.append("- GIDClientID: ⚠ Info.plist に未設定（任意だが推奨）")
        }

        if let photo = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String,
           !photo.isEmpty {
            lines.append("- NSPhotoLibraryUsageDescription: ✓")
        } else {
            lines.append("- NSPhotoLibraryUsageDescription: ⚠ プロフィール画像用に推奨")
        }

        if FirebaseApp.app() != nil {
            lines.append("- FirebaseApp: ✓ 初期化済み")
            if let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty {
                lines.append("- Firebase clientID: ✓")
                if GIDSignIn.sharedInstance.configuration == nil {
                    lines.append("  ⚠ GIDConfiguration 未設定")
                } else {
                    lines.append("- GIDConfiguration: ✓")
                }
                // REVERSED と URL scheme のざっくり一致
                if let googleScheme {
                    let reversedGuess = "com.googleusercontent.apps." + clientID.replacingOccurrences(
                        of: ".apps.googleusercontent.com",
                        with: ""
                    )
                    if googleScheme == reversedGuess {
                        lines.append("- clientID ↔ URL scheme: ✓ 一致")
                    } else {
                        lines.append("- clientID ↔ URL scheme: ⚠ 不一致の可能性")
                        lines.append("  scheme=\(googleScheme)")
                        lines.append("  expect=\(reversedGuess)")
                    }
                }
            } else {
                lines.append("- Firebase clientID: ⚠ なし（GoogleService-Info を確認）")
            }
        } else {
            lines.append("- FirebaseApp: ⚠ 未初期化（plist 配置を確認）")
        }

        lines.append("- Sign in with Apple: entitlements は Xcode Signing & Capabilities で確認（実行時は検証不可）")
        lines.append("- Firebase Auth の Apple/Google 有効化はコンソールで確認")

        print(lines.joined(separator: "\n"))
        #endif
    }

    private static func urlSchemes() -> [String] {
        guard let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] else {
            return []
        }
        return types.flatMap { type -> [String] in
            (type["CFBundleURLSchemes"] as? [String]) ?? []
        }
    }
}
