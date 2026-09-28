//
//  RoomID.swift
//  beer_cheers
//
//  ルーム ID（パス用）の正規化。Model / Repository / URL から共有する。
//

import Foundation

enum RoomID {
    /// `database.rules.json` の `$roomID.length <= 128` と揃える。超えるとルールで拒否される。
    static let maxLength = 128

    /// Realtime Database のキーに使えない文字（`.` を含むと SDK が例外を投げてアプリが落ちる）。
    private static let forbiddenCharacters = CharacterSet(charactersIn: "/.#$[]")
        .union(.controlCharacters)

    /// ルーム名を path 用 ID として正規化する。
    static func normalize(_ raw: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf16.count <= maxLength else {
            throw RoomRepositoryError.invalidRoomName
        }
        guard trimmed.rangeOfCharacter(from: forbiddenCharacters) == nil else {
            throw RoomRepositoryError.invalidRoomName
        }
        return trimmed
    }
}
