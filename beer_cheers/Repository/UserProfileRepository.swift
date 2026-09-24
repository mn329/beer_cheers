//
//  UserProfileRepository.swift
//  beer_cheers
//
//  プロフィールを Realtime Database `users/{uid}/profile` に保存・取得する Repository。
//

import FirebaseDatabase
import Foundation

enum UserProfileRepositoryError: Error {
    case firebaseNotConfigured
    case invalidData
}

protocol UserProfileRepositorying: Sendable {
    func save(uid: String, profile: UserAccountProfile) async throws
    func fetch(uid: String) async throws -> UserAccountProfile?
    func delete(uid: String) async
}

/// 本番用の既定実装。
struct FirebaseUserProfileRepository: UserProfileRepositorying {
    func save(uid: String, profile: UserAccountProfile) async throws {
        try await UserProfileRepository.save(uid: uid, profile: profile)
    }

    func fetch(uid: String) async throws -> UserAccountProfile? {
        try await UserProfileRepository.fetch(uid: uid)
    }

    func delete(uid: String) async {
        await UserProfileRepository.delete(uid: uid)
    }
}

enum UserProfileRepository {
    private static func profileReference(uid: String) -> DatabaseReference {
        Database.database().reference(withPath: "users/\(uid)/profile")
    }

    static func save(uid: String, profile: UserAccountProfile) async throws {
        guard FirebaseBootstrap.isConfigured else {
            throw UserProfileRepositoryError.firebaseNotConfigured
        }
        let value: [String: Any] = [
            "username": profile.username,
            "nickname": profile.nickname,
            "avatarURL": profile.avatarURL ?? "",
            "avatarEmoji": profile.avatarEmoji,
            "updatedAt": Date().timeIntervalSince1970,
        ]
        try await RealtimeDatabaseClient.setValue(profileReference(uid: uid), value)
    }

    static func fetch(uid: String) async throws -> UserAccountProfile? {
        guard FirebaseBootstrap.isConfigured else {
            throw UserProfileRepositoryError.firebaseNotConfigured
        }
        let snapshot = try await RealtimeDatabaseClient.getSnapshot(profileReference(uid: uid))
        guard snapshot.exists(), let dict = snapshot.value as? [String: Any] else {
            return nil
        }
        let username = (dict["username"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nickname = (dict["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawURL = (dict["avatarURL"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarURL = (rawURL?.isEmpty == false) ? rawURL : nil
        let emoji = (dict["avatarEmoji"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let avatarEmoji: String
        if let first = emoji.first {
            avatarEmoji = String(first)
        } else {
            avatarEmoji = UserAccountProfile.default.avatarEmoji
        }
        return UserAccountProfile(
            username: username,
            nickname: nickname.isEmpty ? UserAccountProfile.default.nickname : nickname,
            avatarURL: avatarURL,
            avatarEmoji: avatarEmoji
        )
    }

    static func delete(uid: String) async {
        guard FirebaseBootstrap.isConfigured, !uid.isEmpty else { return }
        do {
            try await RealtimeDatabaseClient.removeValue(
                Database.database().reference(withPath: "users/\(uid)")
            )
        } catch {
            #if DEBUG
                print("[Profile] remote delete skipped: \(error.localizedDescription)")
            #endif
        }
    }
}

typealias UserProfileService = UserProfileRepository
typealias UserProfileServiceError = UserProfileRepositoryError
