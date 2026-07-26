//
//  AccountAuthValidator.swift
//  beer_cheers
//
//  メール/パスワード認証の入力検証。
//

import Foundation

enum AccountAuthValidator {
    private static let emailPattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#

    static func isValidEmail(_ email: String) -> Bool {
        email.range(of: emailPattern, options: .regularExpression) != nil
    }

    static func validateSignIn(email: String, password: String) -> String? {
        if email.isEmpty { return "メールアドレスを入力してください" }
        if !isValidEmail(email) { return "メールアドレスの形式が正しくありません" }
        if password.isEmpty { return "パスワードを入力してください" }
        return nil
    }

    static func validateSignUp(email: String, password: String) -> String? {
        if let signInError = validateSignIn(email: email, password: password) {
            return signInError
        }
        if password.count < 6 { return "パスワードは6文字以上で入力してください" }
        return nil
    }

    static func canSubmitSignIn(email: String, password: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return validateSignIn(email: trimmed, password: password) == nil
    }

    static func canSubmitSignUp(email: String, password: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        return validateSignUp(email: trimmed, password: password) == nil
    }
}
