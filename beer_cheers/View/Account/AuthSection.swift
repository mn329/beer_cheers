//
//  AuthSection.swift
//  beer_cheers
//
//  サインイン / サインアウトのスケルトン。
//  Firebase Auth 結線前は「未実装」を案内表示し、AccountViewModel の signIn/signOut を呼ぶだけにする。
//

import SwiftUI

struct AuthSection: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "サインイン", systemImage: "key.fill")

            switch viewModel.authState {
            case .signedOut:
                signedOutBody
            case .signedIn(let uid, let displayName):
                signedInBody(uid: uid, displayName: displayName)
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.yellow.opacity(0.95))
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(GlassCardBackground())
    }

    private var signedOutBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("サインインすると、表示名やルーム参加情報を端末間で共有できる予定です。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))

            Button {
                viewModel.errorMessage = nil
                Task { await viewModel.signIn() }
            } label: {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("サインインする")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.9))
            .foregroundStyle(.black)
        }
    }

    private func signedInBody(uid: String, displayName: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green.opacity(0.95))
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName ?? "サインイン済み")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("UID: \(uid.prefix(8))…")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Button(role: .destructive) {
                viewModel.signOut()
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("サインアウト")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .tint(.white)
            .foregroundStyle(.white)
        }
    }
}

#Preview {
    ZStack {
        AppBackground()
        AuthSection(viewModel: AccountViewModel())
            .padding()
    }
}
