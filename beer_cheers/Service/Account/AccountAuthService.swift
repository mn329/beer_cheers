//
//  AccountAuthService.swift
//  beer_cheers
//
//  Firebase Auth（Sign in with Apple / Google）。メール／パスワードは使わない。
//

import AuthenticationServices
import CryptoKit
import FirebaseAuth
import Foundation
import GoogleSignIn
import UIKit

enum AccountAuthServiceError: Error {
    case missingPresentingViewController
    case missingGoogleIDToken
    case missingAppleIDToken
    case appleSignInFailed
}

enum AccountAuthService {
    static var currentUser: User? { Auth.auth().currentUser }

    static func signInWithApple() async throws -> User {
        let nonce = AppleSignInNonce.random()
        let appleIDCredential = try await AppleSignInPresenter.shared.signIn(nonce: nonce)
        guard let tokenData = appleIDCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AccountAuthServiceError.missingAppleIDToken
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    static func signInWithGoogle() async throws -> User {
        guard let presenting = TopViewController.current() else {
            throw AccountAuthServiceError.missingPresentingViewController
        }

        let signInResult = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw AccountAuthServiceError.missingGoogleIDToken
        }
        let accessToken = signInResult.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        let result = try await Auth.auth().signIn(with: credential)
        return result.user
    }

    static func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// 未完了の登録をやめるとき用。Auth ユーザーを削除する。
    static func deleteCurrentUser() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
        GIDSignIn.sharedInstance.signOut()
    }

    static func addAuthStateListener(
        _ handler: @escaping @Sendable (User?) -> Void
    ) -> AuthStateDidChangeListenerHandle {
        Auth.auth().addStateDidChangeListener { _, user in
            handler(user)
        }
    }

    static func removeAuthStateListener(_ handle: AuthStateDidChangeListenerHandle) {
        Auth.auth().removeStateDidChangeListener(handle)
    }

    /// Google Sign-In の URL コールバック。処理したら true。
    @discardableResult
    static func handleGoogleURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

// MARK: - Presenting VC

enum TopViewController {
    @MainActor
    static func current() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.first?.windows.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Apple nonce

enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(status)")
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Apple presenter

@MainActor
final class AppleSignInPresenter: NSObject {
    static let shared = AppleSignInPresenter()

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var currentNonce: String?

    func signIn(nonce: String) async throws -> ASAuthorizationAppleIDCredential {
        if continuation != nil {
            throw AccountAuthServiceError.appleSignInFailed
        }
        currentNonce = nonce

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleSignInNonce.sha256(nonce)

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<ASAuthorizationAppleIDCredential, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        currentNonce = nil
        continuation.resume(with: result)
    }
}

extension AppleSignInPresenter: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(AccountAuthServiceError.appleSignInFailed))
            return
        }
        finish(.success(credential))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(.failure(error))
    }
}

extension AppleSignInPresenter: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        if let window = TopViewController.current()?.view.window {
            return window
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        if let key = windows.first(where: \.isKeyWindow) {
            return key
        }
        if let first = windows.first {
            return first
        }
        if let scene = scenes.first {
            return UIWindow(windowScene: scene)
        }
        preconditionFailure("Apple Sign In requires a window scene")
    }
}
