//
//  AccountAuthService.swift
//  beer_cheers
//
//  Created by 石田湊 on 2026/06/03.
//

import FirebaseAuth

enum AccountAuthService {
    //　現在のユーザーを取得するためのプロパティ(いないならnilを返す)
    static var currentUser: User? { Auth.auth().currentUser }

    static func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }

    static func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    static func signOut() throws {
        try Auth.auth().signOut()
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
}
