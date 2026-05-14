//
//  AccountViewModel.swift
//  beer_cheers
//
//  アカウント画面（プロフィール / ルーム切替 / サインイン・アウト / アプリ情報）の状態管理。
//
//  認証は段階的に実装する想定。現段階では:
//   ・プロフィール（表示名・アイコン絵文字）を UserDefaults に保存
//   ・ルーム ID を UserDefaults に保存し、AirCheersViewModel に伝播
//   ・サインイン/アウトのハンドラは "未配線" のままにし、後で Firebase Auth と結ぶ
//

import Observation
import SwiftUI

@MainActor
@Observable
final class AccountViewModel {
    // MARK: - Public state

    var profile: UserAccountProfile
    /// 認証状態。Firebase Auth 結線前は `.signedOut` のまま。
    private(set) var authState: AccountAuthState = .signedOut

    /// 現在の部屋 ID（編集可能）
    var roomID: String

    /// 直近のエラー表示（サインインに失敗した場合などに使う想定）
    var errorMessage: String?

    // MARK: - Persistence keys

    private enum DefaultsKey {
        static let displayName = "account.profile.displayName"
        static let avatarEmoji = "account.profile.avatarEmoji"
        static let roomID = "account.roomID"
    }

    // MARK: - Bridges to other ViewModels

    /// 乾杯画面側に部屋切替を伝えるためのハンドラ。RootTabView で結線する。
    var onRoomChange: ((String) -> Void)?

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        let displayName = defaults.string(forKey: DefaultsKey.displayName) ?? UserAccountProfile.default.displayName
        let avatar = defaults.string(forKey: DefaultsKey.avatarEmoji) ?? UserAccountProfile.default.avatarEmoji
        self.profile = UserAccountProfile(displayName: displayName, avatarEmoji: avatar)
        self.roomID = defaults.string(forKey: DefaultsKey.roomID) ?? CheersRemoteSync.defaultRoomID
    }

    // MARK: - Profile

    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = trimmed.isEmpty ? UserAccountProfile.default.displayName : trimmed
        UserDefaults.standard.set(profile.displayName, forKey: DefaultsKey.displayName)
    }

    func updateAvatarEmoji(_ emoji: String) {
        let candidate = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        // 1 文字（絵文字含む grapheme cluster）に絞る
        guard let first = candidate.first else { return }
        profile.avatarEmoji = String(first)
        UserDefaults.standard.set(profile.avatarEmoji, forKey: DefaultsKey.avatarEmoji)
    }

    // MARK: - Room

    func commitRoomID() {
        let trimmed = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = trimmed.isEmpty ? CheersRemoteSync.defaultRoomID : trimmed
        roomID = final
        UserDefaults.standard.set(final, forKey: DefaultsKey.roomID)
        onRoomChange?(final)
    }

    // MARK: - Auth (Firebase Auth 結線前のスケルトン)

    /// サインインを開始する。
    /// 実装は Firebase Auth を追加してから（指導手順に従って）この本体を埋めていく。
    func signIn() async {
        errorMessage = "サインインは未実装です。Firebase Auth を追加して結線してください。"
    }

    /// サインアウトする。Firebase Auth 結線後に `try Auth.auth().signOut()` を呼ぶ予定。
    func signOut() {
        // 現状はローカル状態のみ初期化（実装後はここで Firebase Auth の signOut を呼ぶ）
        authState = .signedOut
    }
}
