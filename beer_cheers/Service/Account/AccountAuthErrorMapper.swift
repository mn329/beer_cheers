//
//  AccountAuthErrorMapper.swift
//  beer_cheers
//
//  Firebase Auth / IdP エラーを日本語メッセージに変換する。
//

import AuthenticationServices
import FirebaseAuth
import Foundation
import GoogleSignIn

enum AccountAuthErrorMapper {
    private static let fallback = "認証に失敗しました。しばらくしてから再度お試しください。"

    static func message(for error: Error) -> String? {
        if isUserCancellation(error) {
            return nil
        }

        if let serviceError = error as? AccountAuthServiceError {
            switch serviceError {
            case .missingPresentingViewController:
                return "サインイン画面を表示できませんでした"
            case .missingGoogleIDToken, .missingAppleIDToken, .appleSignInFailed:
                return fallback
            }
        }

        let nsError = error as NSError

        if nsError.domain == ASAuthorizationError.errorDomain,
           let code = ASAuthorizationError.Code(rawValue: nsError.code),
           code == .canceled {
            return nil
        }

        if nsError.domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: nsError.code) {
            return message(for: code)
        }

        return fallback
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return true
        }
        // Google Sign-In のキャンセル（ドメイン／コードは SDK 版で揺れうる）
        if nsError.domain.lowercased().contains("gidsignin"),
           nsError.code == -5 || nsError.code == GIDSignInError.canceled.rawValue {
            return true
        }
        return false
    }

    private static func message(for code: AuthErrorCode) -> String {
        switch code {
        case .userDisabled:
            return "このアカウントは無効化されています"
        case .networkError:
            return "ネットワークエラーです。接続を確認してください"
        case .tooManyRequests:
            return "試行回数が多すぎます。しばらくしてから再度お試しください"
        case .accountExistsWithDifferentCredential:
            return "同じメールのアカウントが別の方法で登録されています"
        case .invalidCredential:
            return "認証情報を確認できませんでした。再度お試しください"
        default:
            return fallback
        }
    }
}
