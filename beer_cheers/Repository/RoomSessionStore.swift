//
//  RoomSessionStore.swift
//  beer_cheers
//
//  ルーム ID / メンバー ID の UserDefaults 永続化。
//

import Foundation

enum RoomSessionStore {
    private enum DefaultsKey {
        static let currentRoomID = "room.currentID"
        static let legacyRoomID = "account.roomID"
        static let memberID = "room.memberID"
    }

    /// 端末に紐づく安定したメンバー ID（なければ生成して保存）。
    static func stableMemberID(defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: DefaultsKey.memberID), !saved.isEmpty {
            return saved
        }
        let token = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(12)
            .lowercased()
        let id = "m_\(token)"
        defaults.set(id, forKey: DefaultsKey.memberID)
        return id
    }

    /// 保存済みルーム ID を読み、無ければゲストルームを割り当てる。
    static func loadCurrentRoomID(defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: DefaultsKey.currentRoomID), !saved.isEmpty {
            return resolvedRoomID(saved, defaults: defaults)
        }
        if let legacy = defaults.string(forKey: DefaultsKey.legacyRoomID), !legacy.isEmpty {
            return resolvedRoomID(legacy, defaults: defaults)
        }
        return assignGuestRoomID(defaults: defaults)
    }

    static func saveCurrentRoomID(_ roomID: String, defaults: UserDefaults = .standard) {
        defaults.set(roomID, forKey: DefaultsKey.currentRoomID)
    }

    static func assignGuestRoomID(defaults: UserDefaults = .standard) -> String {
        let id = makeGuestRoomID()
        defaults.set(id, forKey: DefaultsKey.currentRoomID)
        return id
    }

    static func isGuestRoomID(_ roomID: String) -> Bool {
        roomID.hasPrefix("guest_")
    }

    static func makeGuestRoomID() -> String {
        let token = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(10)
            .lowercased()
        return "guest_\(token)"
    }

    private static func resolvedRoomID(_ candidate: String, defaults: UserDefaults) -> String {
        if candidate == CheersRemoteSync.defaultRoomID {
            return assignGuestRoomID(defaults: defaults)
        }
        defaults.set(candidate, forKey: DefaultsKey.currentRoomID)
        return candidate
    }
}
