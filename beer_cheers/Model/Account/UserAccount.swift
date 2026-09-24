//
//  UserAccount.swift
//  beer_cheers
//
//  アカウント画面で扱う「ユーザー像」と認証状態を表す。
//

import Foundation

/// ユーザーの認証状態（Apple / Google、またはゲスト＝signedOut）。
enum AccountAuthState: Equatable, Sendable {
    /// 未サインイン（ゲスト。ローカルプロフィールのみ）
    case signedOut
    /// サインイン済み（最低限の uid と表示名を保持）
    case signedIn(uid: String, displayName: String?)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    var uid: String? {
        if case .signedIn(let uid, _) = self { return uid }
        return nil
    }
}

/// 画面表示用のユーザープロフィール。
/// サインイン後は username / nickname / avatarURL の3点が必須。
/// ユーザー名は英小文字開始・6〜16文字などの厳しめ規約（`ProfileFieldValidator`）。
struct UserAccountProfile: Equatable, Sendable {
    /// ユーザー名（@表示用。半角英数と _）
    var username: String
    /// ニックネーム（ルーム一覧の主表示）
    var nickname: String
    /// Firebase Storage 上のアイコン URL（ゲストは nil）
    var avatarURL: String?
    /// ゲスト／旧データ向けの絵文字フォールバック
    var avatarEmoji: String

    /// ルーム・ヘッダーで主に使う表示名（ニックネーム）
    var displayName: String { nickname }

    /// サインイン後に必須の3点が揃っているか
    var isComplete: Bool {
        !username.isEmpty && !nickname.isEmpty && !(avatarURL ?? "").isEmpty
    }

    static let `default` = UserAccountProfile(
        username: "",
        nickname: "ゲスト",
        avatarURL: nil,
        avatarEmoji: "🍺"
    )

    /// ログアウト後の画面表示用プレースホルダー
    static let placeholder = UserAccountProfile(
        username: "",
        nickname: "ゲスト",
        avatarURL: nil,
        avatarEmoji: "🍺"
    )
}

enum ProfileFieldValidator {
    /// ユーザー名のルール説明（UI 用）
    static let usernameRuleCaption =
        "英小文字で始め、英小文字・数字・_ のみ。6〜16文字。_ の連続・末尾不可"

    private static let reservedUsernames: Set<String> = [
        "admin", "administrator", "root", "system", "support", "official",
        "guest", "ゲスト", "null", "undefined", "me", "you",
        "beercheers", "beer_cheers", "cheers", "moderator", "staff",
    ]

    /// ユーザー名: 厳しめのハンドル規約
    /// - 6〜16文字
    /// - 英小文字で開始
    /// - 使える文字は英小文字・数字・アンダースコアのみ
    /// - アンダースコアの連続・末尾禁止
    /// - 予約語禁止
    static func validateUsername(_ raw: String) -> String? {
        let username = normalizeUsername(raw)
        if username.isEmpty { return "ユーザー名を入力してください" }
        if username.count < 6 { return "ユーザー名は6文字以上にしてください" }
        if username.count > 16 { return "ユーザー名は16文字以内にしてください" }

        let pattern = #"^[a-z][a-z0-9_]*$"#
        guard username.range(of: pattern, options: .regularExpression) != nil else {
            return "先頭は英小文字、使える文字は英小文字・数字・_ のみです"
        }
        if username.hasSuffix("_") {
            return "ユーザー名の末尾に _ は使えません"
        }
        if username.contains("__") {
            return "アンダースコアを連続では使えません"
        }
        if reservedUsernames.contains(username) {
            return "このユーザー名は使用できません"
        }
        return nil
    }

    static func validateNickname(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "ニックネームを入力してください" }
        if trimmed.count > 24 { return "ニックネームは24文字以内にしてください" }
        return nil
    }

    static func normalizeUsername(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizeNickname(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
