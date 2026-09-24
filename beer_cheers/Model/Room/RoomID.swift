//
//  RoomID.swift
//  beer_cheers
//
//  ルーム ID（パス用）の正規化。Model / Repository / URL から共有する。
//

import Foundation

enum RoomID {
    /// ルーム名を path 用 ID として正規化する。
    static func normalize(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RoomRepositoryError.invalidRoomName }
        let forbidden = CharacterSet(charactersIn: "/#$[]")
        guard trimmed.rangeOfCharacter(from: forbidden) == nil else {
            throw RoomRepositoryError.invalidRoomName
        }
        return trimmed
    }
}
