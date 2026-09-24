//
//  StartFlowStore.swift
//  beer_cheers
//
//  スタート（ようこそ／認証）完了フラグ。ゲストでも完了扱いにする。
//

import Foundation

enum StartFlowStore {
    private static let completedKey = "startFlow.completed"

    static var hasCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: completedKey) }
    }

    static func markCompleted() {
        hasCompleted = true
    }
}
