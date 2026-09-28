//
//  TutorialStore.swift
//  beer_cheers
//
//  初回チュートリアル（使い方ガイド）の完了フラグ。スキップしても完了扱いにする。
//

import Foundation

enum TutorialStore {
    private enum DefaultsKey {
        static let completed = "tutorial.completed"
        static let existingUserChecked = "tutorial.existingUserChecked"
    }

    static func hasCompleted(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: DefaultsKey.completed)
    }

    static func markCompleted(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: DefaultsKey.completed)
    }

    /// ガイド追加前から使っている人には出さない。
    /// 判定は最初の起動で一度だけ行い、新規ユーザーがガイド途中で終了しても次回また出るようにする。
    static func skipForExistingUserOnce(isExistingUser: Bool, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: DefaultsKey.existingUserChecked) else { return }
        defaults.set(true, forKey: DefaultsKey.existingUserChecked)
        if isExistingUser {
            markCompleted(defaults: defaults)
        }
    }
}
