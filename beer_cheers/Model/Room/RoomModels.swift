//
//  RoomModels.swift
//  beer_cheers
//
//  ルーム作成・参加で使うモデルとエラー。
//

import Foundation

/// ルーム参加時のパスワード照合方針。
enum RoomJoinPasswordPolicy: Sendable {
    /// 名前参加: meta のパスワードと照合する。
    case requireMatch
    /// URL 招待: パスワードは見ない（meta の存在のみ確認）。
    case inviteURL
}

/// ルームタブの作成 / 参加モード。
enum RoomMode: String, CaseIterable, Identifiable, Sendable {
    case create
    case join

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create: "作成"
        case .join: "参加"
        }
    }

    var actionTitle: String {
        switch self {
        case .create: "作成する"
        case .join: "参加する"
        }
    }
}

/// Realtime Database `rooms/{roomID}/meta` の内容。
struct RoomMeta: Equatable, Sendable {
    var name: String
    /// 空または nil ならパスワードなし。
    var password: String?
    var createdAt: TimeInterval
    /// ホストの memberID。旧データでは nil のことがある。
    var hostMemberID: String?

    var requiresPassword: Bool {
        guard let password else { return false }
        return !password.isEmpty
    }

    func matches(password candidate: String?) -> Bool {
        guard requiresPassword else { return true }
        let entered = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return entered == password
    }

    func asFirebaseValue() -> [String: Any] {
        var value: [String: Any] = [
            "name": name,
            "createdAt": createdAt,
        ]
        if let password, !password.isEmpty {
            value["password"] = password
        }
        if let hostMemberID, !hostMemberID.isEmpty {
            value["hostMemberID"] = hostMemberID
        }
        return value
    }

    static func fromFirebaseValue(_ value: Any?, fallbackName: String) -> RoomMeta? {
        guard let dict = value as? [String: Any] else { return nil }
        let rawName = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName: String
        if let rawName, !rawName.isEmpty {
            resolvedName = rawName
        } else {
            resolvedName = fallbackName
        }
        let password = dict["password"] as? String
        let createdAt = (dict["createdAt"] as? NSNumber)?.doubleValue
            ?? (dict["createdAt"] as? Double)
            ?? Date().timeIntervalSince1970
        let host = (dict["hostMemberID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return RoomMeta(
            name: resolvedName,
            password: password,
            createdAt: createdAt,
            hostMemberID: (host?.isEmpty == false) ? host : nil
        )
    }
}

/// Realtime Database `rooms/{roomID}/members/{memberID}` の内容。
struct RoomMember: Identifiable, Equatable, Sendable {
    var id: String
    /// ニックネーム（主表示）
    var nickname: String
    /// ユーザー名（小さく @ 表示。ゲストは空）
    var username: String
    /// Storage 上のアイコン URL（無ければ絵文字フォールバック）
    var avatarURL: String?
    /// ゲスト／旧データ向け
    var avatarEmoji: String
    var joinedAt: TimeInterval

    /// 互換・呼び出し側向けの主表示名
    var displayName: String { nickname }

    func asFirebaseValue() -> [String: Any] {
        var value: [String: Any] = [
            "nickname": nickname,
            "username": username,
            "displayName": nickname, // 旧クライアント互換
            "avatarEmoji": avatarEmoji,
            "joinedAt": joinedAt,
        ]
        if let avatarURL, !avatarURL.isEmpty {
            value["avatarURL"] = avatarURL
        }
        return value
    }

    static func fromFirebaseValue(id: String, value: Any?) -> RoomMember? {
        guard let dict = value as? [String: Any] else { return nil }

        let rawNickname = (dict["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawDisplay = (dict["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nickname: String
        if let rawNickname, !rawNickname.isEmpty {
            nickname = rawNickname
        } else if let rawDisplay, !rawDisplay.isEmpty {
            nickname = rawDisplay
        } else {
            nickname = "ゲスト"
        }

        let rawUsername = (dict["username"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = rawUsername ?? ""

        let rawURL = (dict["avatarURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarURL = (rawURL?.isEmpty == false) ? rawURL : nil

        let rawEmoji = (dict["avatarEmoji"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarEmoji: String
        if let rawEmoji, let first = rawEmoji.first {
            avatarEmoji = String(first)
        } else {
            avatarEmoji = "🍺"
        }

        let joinedAt = (dict["joinedAt"] as? NSNumber)?.doubleValue
            ?? (dict["joinedAt"] as? Double)
            ?? 0
        return RoomMember(
            id: id,
            nickname: nickname,
            username: username,
            avatarURL: avatarURL,
            avatarEmoji: avatarEmoji,
            joinedAt: joinedAt
        )
    }
}
