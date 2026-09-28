//
//  RoomRepositoryError.swift
//  beer_cheers
//
//  ルーム Repository 操作のエラー。Firebase コールバック（nonisolated）からも使う。
//

import Foundation

nonisolated enum RoomRepositoryError: LocalizedError, Equatable, Sendable {
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
            "ルーム名が無効です。空や128文字を超える名前、/ . # $ [ ] は使えません。"
        case .roomAlreadyExists:
            "同じ名前のルームが既に存在します。"
        case .roomNotFound:
            "ルームが見つかりません。名前を確認するか、先に作成してください。"
        case .wrongPassword:
            "パスワードが違います。"
        case .networkUnavailable:
            "ネットワークに接続できないため、ルーム情報を取得できませんでした。通信環境を確認して再度お試しください。"
        case .permissionDenied:
            "ルームの操作が許可されませんでした。ルーム名やプロフィールの内容を確認して、もう一度お試しください。"
        case .notHost:
            "ホストだけが操作できます。"
        case .invalidHostCandidate:
            "そのメンバーにはホストを譲渡できません。"
        }
    }
}