//
//  AccountViewModel.swift
//  beer_cheers
//
//  アカウント画面の状態管理。プロフィールはローカル＋ Repository 経由でリモート保存する。
//

import FirebaseAuth
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class AccountViewModel {

    var profile: UserAccountProfile

    private(set) var authState: AccountAuthState = .signedOut
    /// サインイン／サインアウト／アカウント削除など認証まわりのエラー（アカウント画面用）
    var errorMessage: String?
    /// プロフィール入力・保存のエラー（編集／セットアップ画面用。アカウント画面には出さない）
    var profileErrorMessage: String?
    private(set) var isAuthLoading = false
    private(set) var isProfileSaving = false
    private(set) var isProfileRestoring = false

    /// サインイン済みかつ必須プロフィール未完了
    var needsProfileSetup: Bool {
        authState.isSignedIn && !profile.isComplete && !isProfileRestoring
    }

    private let profileRepository: any UserProfileRepositorying
    private let avatarRepository: any ProfileAvatarRepositorying
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Init

    init(
        profileRepository: any UserProfileRepositorying = FirebaseUserProfileRepository(),
        avatarRepository: any ProfileAvatarRepositorying = FirebaseProfileAvatarRepository()
    ) {
        self.profileRepository = profileRepository
        self.avatarRepository = avatarRepository
        self.profile = .placeholder
        refreshAuthState()
        if authState.isSignedIn {
            self.profile = LocalProfileStore.load()
        } else {
            LocalProfileStore.removeAll()
        }
    }

    // MARK: - Profile

    func updateUsername(_ name: String) {
        profile.username = ProfileFieldValidator.normalizeUsername(name)
        LocalProfileStore.saveUsername(profile.username)
    }

    func updateNickname(_ name: String) {
        let normalized = ProfileFieldValidator.normalizeNickname(name)
        profile.nickname = normalized.isEmpty
            ? UserAccountProfile.default.nickname
            : normalized
        LocalProfileStore.saveNickname(profile.nickname)
    }

    func updateAvatarURL(_ urlString: String?) {
        profile.avatarURL = urlString
        LocalProfileStore.saveAvatarURL(urlString)
    }

    /// テキストのみ更新したあと、リモートにも保存する。
    func saveProfileFields(username: String, nickname: String) async -> Bool {
        profileErrorMessage = nil
        if let usernameError = ProfileFieldValidator.validateUsername(username) {
            profileErrorMessage = usernameError
            return false
        }
        if let nicknameError = ProfileFieldValidator.validateNickname(nickname) {
            profileErrorMessage = nicknameError
            return false
        }
        guard profile.avatarURL != nil else {
            profileErrorMessage = "プロフィール画像を選んでください"
            return false
        }
        updateUsername(username)
        updateNickname(nickname)
        return await persistProfileToRemote()
    }

    /// サインイン後の必須3点をまとめて保存（画像は Storage、メタは RTDB）。
    @discardableResult
    func completeProfile(
        username: String,
        nickname: String,
        image: UIImage
    ) async -> Bool {
        profileErrorMessage = nil

        if let usernameError = ProfileFieldValidator.validateUsername(username) {
            profileErrorMessage = usernameError
            return false
        }
        if let nicknameError = ProfileFieldValidator.validateNickname(nickname) {
            profileErrorMessage = nicknameError
            return false
        }
        guard let uid = authState.uid else {
            profileErrorMessage = "サインインしてからプロフィールを設定してください"
            return false
        }
        guard let jpeg = ProfileAvatarRepository.jpegData(from: image) else {
            profileErrorMessage = "画像を処理できませんでした"
            return false
        }

        isProfileSaving = true
        defer { isProfileSaving = false }

        do {
            let url = try await avatarRepository.uploadAvatarJPEGData(jpeg, uid: uid)
            updateUsername(username)
            updateNickname(nickname)
            updateAvatarURL(url.absoluteString)
            try await profileRepository.save(uid: uid, profile: profile)
            return true
        } catch {
            profileErrorMessage = "プロフィールの保存に失敗しました。通信を確認してください"
            #if DEBUG
                print("[Profile] save failed: \(error.localizedDescription)")
            #endif
            return false
        }
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
                guard let self else { return }
                let wasSignedIn = self.authState.isSignedIn
                let previousUID = self.authState.uid
                self.authState = nextState

                if case .signedOut = nextState {
                    if wasSignedIn {
                        self.clearProfileToPlaceholder()
                    }
                    return
                }

                if case .signedIn(let uid, _) = nextState, uid != previousUID || !self.profile.isComplete {
                    await self.restoreProfileFromRemote(uid: uid)
                }
            }
        }

        if let uid = authState.uid {
            Task { await restoreProfileFromRemote(uid: uid) }
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

    /// Google サインインの URL コールバック。処理したら true。
    @discardableResult
    func handleIncomingAuthURL(_ url: URL) -> Bool {
        AccountAuthService.handleGoogleURL(url)
    }

    @discardableResult
    func signInWithApple() async -> Bool {
        await performSignIn {
            _ = try await AccountAuthService.signInWithApple()
        }
    }

    @discardableResult
    func signInWithGoogle() async -> Bool {
        await performSignIn {
            _ = try await AccountAuthService.signInWithGoogle()
        }
    }

    func signOut() {
        do {
            try AccountAuthService.signOut()
            errorMessage = nil
            profileErrorMessage = nil
            clearProfileToPlaceholder()
            authState = .signedOut
        } catch {
            errorMessage = AccountAuthErrorMapper.message(for: error)
                ?? "サインアウトに失敗しました"
        }
    }

    func cancelIncompleteRegistration() async {
        errorMessage = nil
        profileErrorMessage = nil
        isProfileSaving = true
        defer { isProfileSaving = false }

        await deleteRemoteProfileAssetsIfNeeded()

        do {
            try await AccountAuthService.deleteCurrentUser()
        } catch {
            #if DEBUG
                print("[Auth] delete user failed, signOut instead: \(error.localizedDescription)")
            #endif
            try? AccountAuthService.signOut()
        }

        clearProfileToPlaceholder()
        authState = .signedOut
    }

    @discardableResult
    func deleteAccount() async -> Bool {
        errorMessage = nil
        profileErrorMessage = nil
        guard authState.isSignedIn else {
            errorMessage = "サインインしていません"
            return false
        }

        isProfileSaving = true
        defer { isProfileSaving = false }

        await deleteRemoteProfileAssetsIfNeeded()

        do {
            try await AccountAuthService.deleteCurrentUser()
            clearProfileToPlaceholder()
            authState = .signedOut
            return true
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain,
               let code = AuthErrorCode(rawValue: nsError.code),
               code == .requiresRecentLogin {
                errorMessage = "セキュリティのため、一度サインアウトして再サインインしてから削除してください"
            } else {
                errorMessage = AccountAuthErrorMapper.message(for: error)
                    ?? "アカウントの削除に失敗しました"
            }
            #if DEBUG
                print("[Auth] deleteAccount failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    func clearProfileToPlaceholder() {
        profile = .placeholder
        LocalProfileStore.removeAll()
    }

    // MARK: - Remote restore / persist

    private func deleteRemoteProfileAssetsIfNeeded() async {
        let uid = authState.uid ?? AccountAuthService.currentUser?.uid
        guard let uid else { return }
        await avatarRepository.deleteAvatarIfExists(uid: uid)
        await profileRepository.delete(uid: uid)
    }

    private func restoreProfileFromRemote(uid: String) async {
        isProfileRestoring = true
        defer { isProfileRestoring = false }

        do {
            if let remote = try await profileRepository.fetch(uid: uid), remote.isComplete {
                applyLoadedProfile(remote)
                #if DEBUG
                    print("[Profile] restored from remote for uid \(uid.prefix(8))…")
                #endif
            }
        } catch {
            #if DEBUG
                print("[Profile] restore failed: \(error.localizedDescription)")
            #endif
        }
    }

    @discardableResult
    private func persistProfileToRemote() async -> Bool {
        guard let uid = authState.uid else { return false }
        do {
            try await profileRepository.save(uid: uid, profile: profile)
            return true
        } catch {
            profileErrorMessage = "プロフィールの同期に失敗しました"
            #if DEBUG
                print("[Profile] persist failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    private func applyLoadedProfile(_ loaded: UserAccountProfile) {
        profile = loaded
        LocalProfileStore.save(loaded)
    }

    private func performSignIn(_ work: () async throws -> Void) async -> Bool {
        errorMessage = nil
        profileErrorMessage = nil
        isAuthLoading = true
        defer { isAuthLoading = false }

        do {
            try await work()
            refreshAuthState()
            if let uid = authState.uid {
                await restoreProfileFromRemote(uid: uid)
            }
            return true
        } catch {
            errorMessage = AccountAuthErrorMapper.message(for: error)
            return false
        }
    }

    private func applyAuthState(from user: User?) {
        if let user {
            authState = .signedIn(uid: user.uid, displayName: user.displayName)
        } else {
            authState = .signedOut
        }
    }
}
