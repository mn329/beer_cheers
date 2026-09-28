//
//  RecentRoomStore.swift
//  beer_cheers
//
//  最近入ったルーム名の履歴（新しい順）を UserDefaults に保存する。
//

import Foundation

enum RecentRoomStore {
    static let maxCount = 5
    private static let key = "room.recentIDs"

    static func load(defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    /// 先頭に追加する。同じルームは重複させず先頭へ移し、ゲストルームは記録しない。
    @discardableResult
    static func record(_ roomID: String, defaults: UserDefaults = .standard) -> [String] {
        guard !RoomSessionStore.isGuestRoomID(roomID) else { return load(defaults: defaults) }
        let updated = Array(([roomID] + load(defaults: defaults).filter { $0 != roomID }).prefix(maxCount))
        defaults.set(updated, forKey: key)
        return updated
    }

    @discardableResult
    static func remove(_ roomID: String, defaults: UserDefaults = .standard) -> [String] {
        let updated = load(defaults: defaults).filter { $0 != roomID }
        defaults.set(updated, forKey: key)
        return updated
    }
}
