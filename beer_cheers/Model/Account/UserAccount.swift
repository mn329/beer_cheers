//
//  UserAccount.swift
//  beer_cheers
//
//  アカウント画面で扱う「ユーザー像」と認証状態を表す。
//  Firebase Auth 実装時はここに UID 等を追加して紐付ける。
//

import Foundation

/// ユーザーの認証状態。Firebase Auth 接続前は `.signedOut` 固定で動作する。
enum AccountAuthState: Equatable, Sendable {
    /// 未サインイン（ローカルプロフィールのみ）
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
/// 端末ローカルの値（UserDefaults 等）と認証済み値の両方を抱え、
/// 表示は「優先順位：認証済み値 → ローカル」で解決する想定。
struct UserAccountProfile: Equatable, Sendable {
    /// 表示名（ローカル編集可）
    var displayName: String
    /// アイコン用の絵文字
    var avatarEmoji: String

    static let `default` = UserAccountProfile(
        displayName: "ゲスト",
        avatarEmoji: "🍺"
    )
}
