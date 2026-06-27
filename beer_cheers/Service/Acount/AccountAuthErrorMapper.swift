//
//  AccountAuthErrorMapper.swift
//  beer_cheers
//
//  Firebase Auth エラーを日本語メッセージに変換する。
//

import FirebaseAuth
import Foundation

enum AccountAuthErrorMapper {
    private static let fallback = "認証に失敗しました。しばらくしてから再度お試しください。"

    static func message(for error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code)
        else {
            return fallback
        }
        return message(for: code)
    }

    private static func message(for code: AuthErrorCode) -> String {
        switch code {
        case .invalidEmail:
            return "メールアドレスの形式が正しくありません"
        case .userDisabled:
            return "このアカウントは無効化されています"
        case .emailAlreadyInUse:
            return "このメールアドレスは既に使用されています"
        case .wrongPassword, .invalidCredential:
            return "メールアドレスまたはパスワードが正しくありません"
        case .userNotFound:
            return "メールアドレスまたはパスワードが正しくありません"
        case .weakPassword:
            return "パスワードは6文字以上で入力してください"
        case .networkError:
            return "ネットワークエラーです。接続を確認してください"
        case .tooManyRequests:
            return "試行回数が多すぎます。しばらくしてから再度お試しください"
        default:
            return fallback
        }
    }
}
