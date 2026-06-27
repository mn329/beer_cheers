//
//  AccountViewModel.swift
//  beer_cheers
//
//  アカウント画面の状態管理
//

import Observation
import SwiftUI
import FirebaseAuth

@MainActor
@Observable
final class AccountViewModel {

    var profile: UserAccountProfile
    var roomID: String
    var onRoomChange: ((String) -> Void)?

    private enum DefaultsKey {
        static let displayName = "account.profile.displayName"
        static let avatarEmoji = "account.profile.avatarEmoji"
        static let roomID = "account.roomID"
    }

    // 認証状態(private(set)でviewからの変更を禁止)
    private(set) var authState: AccountAuthState = .signedOut
    //　エラーメッセージ（サインイン・サインアップ失敗時など）
    var errorMessage: String?
    // 認証 API 呼び出し中
    private(set) var isAuthLoading = false

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        let displayName = defaults.string(forKey: DefaultsKey.displayName)
            ?? UserAccountProfile.default.displayName
        let avatar = defaults.string(forKey: DefaultsKey.avatarEmoji)
            ?? UserAccountProfile.default.avatarEmoji
        self.profile = UserAccountProfile(displayName: displayName, avatarEmoji: avatar)
        self.roomID = defaults.string(forKey: DefaultsKey.roomID) ?? "test_room"
    }

    // MARK: - Profile

    func updateDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.displayName = trimmed.isEmpty
        ? UserAccountProfile.default.displayName
        : trimmed
        UserDefaults.standard.set(profile.displayName, forKey: DefaultsKey.displayName)
    }

    func updateAvatarEmoji(_ emoji: String) {
        let candidate = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = candidate.first else { return }
        profile.avatarEmoji = String(first)
        UserDefaults.standard.set(profile.avatarEmoji, forKey: DefaultsKey.avatarEmoji)
    }

    // MARK: - Room

    func commitRoomID() {
        let trimmed = roomID.trimmingCharacters(in: .whitespacesAndNewlines)
        let final = trimmed.isEmpty ? CheersRemoteSync.defaultRoomID : trimmed
        roomID = final
        UserDefaults.standard.set(final, forKey: DefaultsKey.roomID)
        onRoomChange?(final)
    }

    // MARK: - Authentication

    func startObservingAuthState() {
        guard authStateListenerHandle == nil else { return }
        refreshAuthState()
        authStateListenerHandle = AccountAuthService.addAuthStateListener { [weak self] user in
            let nextState: AccountAuthState
            if let user {
                nextState = .signedIn(uid: user.uid, displayName: user.displayName)
            } else {
                nextState = .signedOut
            }
            Task { @MainActor [weak self] in
                self?.authState = nextState
            }
        }
    }

    func stopObservingAuthState() {
        guard let handle = authStateListenerHandle else { return }
        AccountAuthService.removeAuthStateListener(handle)
        authStateListenerHandle = nil
    }

    func refreshAuthState() {
        applyAuthState(from: AccountAuthService.currentUser)
    }

    func signUp(email: String, password: String) async {
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = AccountAuthValidator.validateSignUp(
            email: trimmedEmail, password: password
        ) {
            errorMessage = validationError
            return
        }

        isAuthLoading = true
        defer { isAuthLoading = false }

        do {
            _ = try await AccountAuthService.signUp(email: trimmedEmail, password: password)
        } catch {
            errorMessage = AccountAuthErrorMapper.message(for: error)
        }
    }

    func signIn(email: String, password: String) async {
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = AccountAuthValidator.validateSignIn(
            email: trimmedEmail, password: password
        ) {
            errorMessage = validationError
            return
        }

        isAuthLoading = true
        defer { isAuthLoading = false }

        do {
            _ = try await AccountAuthService.signIn(email: trimmedEmail, password: password)
        } catch {
            errorMessage = AccountAuthErrorMapper.message(for: error)
        }
    }

    func signOut() {
        try? AccountAuthService.signOut()
        errorMessage = nil
    }

    private func applyAuthState(from user: User?) {
        if let user {
            authState = .signedIn(uid: user.uid, displayName: user.displayName)
        } else {
            authState = .signedOut
        }
    }
}
