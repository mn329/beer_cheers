//
//  RoomModels.swift
//  beer_cheers
//
//  ルーム作成・参加で使うモデルとエラー。
//

import Foundation

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
    var displayName: String
    var avatarEmoji: String
    var joinedAt: TimeInterval

    func asFirebaseValue() -> [String: Any] {
        [
            "displayName": displayName,
            "avatarEmoji": avatarEmoji,
            "joinedAt": joinedAt,
        ]
    }

    static func fromFirebaseValue(id: String, value: Any?) -> RoomMember? {
        guard let dict = value as? [String: Any] else { return nil }
        let rawName = (dict["displayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName: String
        if let rawName, !rawName.isEmpty {
            displayName = rawName
        } else {
            displayName = "ゲスト"
        }
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
            displayName: displayName,
            avatarEmoji: avatarEmoji,
            joinedAt: joinedAt
        )
    }
}

enum RoomServiceError: LocalizedError, Equatable {
    case firebaseNotConfigured
    case invalidRoomName
    case roomAlreadyExists
    case roomNotFound
    case wrongPassword
    case networkUnavailable
    case permissionDenied
    case notHost
    case invalidHostCandidate

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            "Firebase が未設定のため、ルーム操作ができません。"
        case .invalidRoomName:
            "ルーム名が無効です。空や / # $ [ ] は使えません。"
        case .roomAlreadyExists:
            "同じ名前のルームが既に存在します。"
        case .roomNotFound:
            "ルームが見つかりません。名前を確認するか、先に作成してください。"
        case .wrongPassword:
            "パスワードが違います。"
        case .networkUnavailable:
            "ネットワークに接続できないため、ルーム情報を取得できませんでした。通信環境を確認して再度お試しください。"
        case .permissionDenied:
            "データベースへのアクセスが拒否されました。Firebase の Realtime Database ルールで rooms の読み書きを許可するか、アカウントでサインインしてから再度お試しください。"
        case .notHost:
            "ホストだけが操作できます。"
        case .invalidHostCandidate:
            "そのメンバーにはホストを譲渡できません。"
        }
    }
}
