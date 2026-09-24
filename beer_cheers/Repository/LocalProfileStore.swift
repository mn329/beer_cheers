//
//  LocalProfileStore.swift
//  beer_cheers
//
//  プロフィールの UserDefaults キャッシュ（端末ローカル）。
//

import Foundation

enum LocalProfileStore {
    private enum DefaultsKey {
        static let username = "account.profile.username"
        static let nickname = "account.profile.nickname"
        static let avatarURL = "account.profile.avatarURL"
        static let avatarEmoji = "account.profile.avatarEmoji"
        static let legacyDisplayName = "account.profile.displayName"
    }

    static func load() -> UserAccountProfile {
        let defaults = UserDefaults.standard
        let username = defaults.string(forKey: DefaultsKey.username) ?? ""
        let nickname = defaults.string(forKey: DefaultsKey.nickname)
            ?? defaults.string(forKey: DefaultsKey.legacyDisplayName)
            ?? UserAccountProfile.default.nickname
        let avatarURL = defaults.string(forKey: DefaultsKey.avatarURL)
        let avatarEmoji = defaults.string(forKey: DefaultsKey.avatarEmoji)
            ?? UserAccountProfile.default.avatarEmoji
        return UserAccountProfile(
            username: username,
            nickname: nickname,
            avatarURL: avatarURL,
            avatarEmoji: avatarEmoji
        )
    }

    static func save(_ profile: UserAccountProfile) {
        let defaults = UserDefaults.standard
        defaults.set(profile.username, forKey: DefaultsKey.username)
        defaults.set(profile.nickname, forKey: DefaultsKey.nickname)
        if let url = profile.avatarURL {
            defaults.set(url, forKey: DefaultsKey.avatarURL)
        } else {
            defaults.removeObject(forKey: DefaultsKey.avatarURL)
        }
        defaults.set(profile.avatarEmoji, forKey: DefaultsKey.avatarEmoji)
    }

    static func saveUsername(_ username: String) {
        UserDefaults.standard.set(username, forKey: DefaultsKey.username)
    }

    static func saveNickname(_ nickname: String) {
        UserDefaults.standard.set(nickname, forKey: DefaultsKey.nickname)
    }

    static func saveAvatarURL(_ urlString: String?) {
        if let urlString, !urlString.isEmpty {
            UserDefaults.standard.set(urlString, forKey: DefaultsKey.avatarURL)
        } else {
            UserDefaults.standard.removeObject(forKey: DefaultsKey.avatarURL)
        }
    }

    static func removeAll() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.username)
        defaults.removeObject(forKey: DefaultsKey.nickname)
        defaults.removeObject(forKey: DefaultsKey.avatarURL)
        defaults.removeObject(forKey: DefaultsKey.avatarEmoji)
        defaults.removeObject(forKey: DefaultsKey.legacyDisplayName)
    }
}
