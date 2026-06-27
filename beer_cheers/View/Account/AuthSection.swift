//
//  AuthSection.swift
//  beer_cheers
//
//  メール/パスワードによるサインイン・アカウント作成 UI。
//

import SwiftUI

struct AuthSection: View {
    @Bindable var viewModel: AccountViewModel

    @State private var draftEmail: String = ""
    @State private var draftPassword: String = ""
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var canSignIn: Bool {
        AccountAuthValidator.canSubmitSignIn(email: draftEmail, password: draftPassword)
    }

    private var canSignUp: Bool {
        AccountAuthValidator.canSubmitSignUp(email: draftEmail, password: draftPassword)
    }

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
                    .foregroundStyle(AccountContentStyle.error)
            }
        }
        .padding(16)
        .background(GlassCardBackground())
    }

    // MARK: - Signed out

    private var signedOutBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("メールとパスワードでログイン、または新規アカウントを作成できます。")
                .font(.footnote)
                .foregroundStyle(AccountContentStyle.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("メール")
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.secondary)
                TextField("email@example.com", text: $draftEmail)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .password }
                    .disabled(viewModel.isAuthLoading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(GlassFieldBackground())
                    .foregroundStyle(AccountContentStyle.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("パスワード")
                    .font(.footnote)
                    .foregroundStyle(AccountContentStyle.secondary)
                SecureField("6文字以上", text: $draftPassword)
                    .textContentType(.password)
                    .focused($focusedField, equals: .password)
                    .submitLabel(.go)
                    .onSubmit { signIn() }
                    .disabled(viewModel.isAuthLoading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(GlassFieldBackground())
                    .foregroundStyle(AccountContentStyle.primary)
            }

            if viewModel.isAuthLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AccountContentStyle.primary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }

            Button(action: signIn) {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("ログイン")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white.opacity(0.9))
            .foregroundStyle(.black)
            .disabled(!canSignIn || viewModel.isAuthLoading)

            Button(action: signUp) {
                HStack {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("アカウント作成")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .tint(AccountContentStyle.primary)
            .foregroundStyle(AccountContentStyle.primary)
            .disabled(!canSignUp || viewModel.isAuthLoading)
        }
    }

    // MARK: - Signed in

    private func signedInBody(uid: String, displayName: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green.opacity(0.95))
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName ?? "サインイン済み")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AccountContentStyle.primary)
                    Text("UID: \(uid.prefix(8))…")
                        .font(.caption2.monospaced())
                        .foregroundStyle(AccountContentStyle.secondary)
                }
            }

            Button(role: .destructive) {
                viewModel.signOut()
                clearDrafts()
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
            .tint(AccountContentStyle.primary)
            .foregroundStyle(AccountContentStyle.primary)
            .disabled(viewModel.isAuthLoading)
        }
    }

    // MARK: - Actions

    private func signIn() {
        guard canSignIn, !viewModel.isAuthLoading else { return }
        viewModel.errorMessage = nil
        focusedField = nil
        Task {
            await viewModel.signIn(email: draftEmail, password: draftPassword)
        }
    }

    private func signUp() {
        guard canSignUp, !viewModel.isAuthLoading else { return }
        viewModel.errorMessage = nil
        focusedField = nil
        Task {
            await viewModel.signUp(email: draftEmail, password: draftPassword)
        }
    }

    private func clearDrafts() {
        draftEmail = ""
        draftPassword = ""
    }
}

#Preview {
    ZStack {
        AppBackground()
        AuthSection(viewModel: AccountViewModel())
            .padding()
    }
}
