//
//  AccountView.swift
//  beer_cheers
//
//  アカウントタブ。サインイン時のみヘッダーから編集画面へ遷移する。
//

import SwiftUI

struct AccountView: View {
    @Bindable var viewModel: AccountViewModel

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                        .padding(.top, 8)

                    if !viewModel.authState.isSignedIn {
                        VStack(alignment: .leading, spacing: 12) {
                            SocialAuthButtons(
                                isLoading: viewModel.isAuthLoading,
                                onApple: { Task { await viewModel.signInWithApple() } },
                                onGoogle: { Task { await viewModel.signInWithGoogle() } }
                            )
                        }
                        .padding(16)
                        .background(GlassCardBackground())
                    }

                    if let message = viewModel.errorMessage, !viewModel.authState.isSignedIn {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AccountContentStyle.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }

                    AboutSection()
                }
            }
            .contentMargins(
                .bottom,
                TabContentLayout.floatingTabBarClearance,
                for: .scrollContent
            )
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onAppear {
            viewModel.refreshAuthState()
        }
    }

    @ViewBuilder
    private var header: some View {
        if viewModel.authState.isSignedIn {
            NavigationLink {
                AccountEditView(viewModel: viewModel)
            } label: {
                AccountHeaderView(
                    profile: viewModel.profile,
                    isSignedIn: true,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("タップしてプロフィール編集へ")
        } else {
            // ゲストは編集画面へ遷移しない
            AccountHeaderView(
                profile: viewModel.profile,
                isSignedIn: false,
                showsChevron: false
            )
        }
    }
}

// MARK: - Edit

struct AccountEditView: View {
    @Bindable var viewModel: AccountViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    ProfileSection(viewModel: viewModel)

                    if viewModel.authState.isSignedIn {
                        accountActionsCard
                    }

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AccountContentStyle.error)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .contentMargins(
                .bottom,
                TabContentLayout.floatingTabBarClearance,
                for: .scrollContent
            )
        }
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .onDisappear {
            viewModel.profileErrorMessage = nil
        }
        .alert("アカウントを削除しますか？", isPresented: $showDeleteConfirm) {
            Button("削除する", role: .destructive) {
                Task {
                    let ok = await viewModel.deleteAccount()
                    if ok { dismiss() }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("プロフィール画像とサインイン情報が削除され、元に戻せません。")
        }
    }

    private var accountActionsCard: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.signOut()
                dismiss()
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
            .disabled(viewModel.isAuthLoading || viewModel.isProfileSaving)

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("アカウントを削除")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
            .buttonStyle(.bordered)
            .tint(AccountContentStyle.error)
            .foregroundStyle(AccountContentStyle.error)
            .disabled(viewModel.isProfileSaving)
        }
        .padding(16)
        .background(GlassCardBackground())
    }
}

#Preview {
    NavigationStack {
        AccountView(viewModel: AccountViewModel())
    }
}
