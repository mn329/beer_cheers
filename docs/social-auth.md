# Sign in with Apple / Google

スタート画面とアカウントタブで使う認証。メール／パスワードは使わない（パスワード再設定用ドメインが不要なため）。**ゲストではじめる**も可能。

## Xcode 側（リポジトリで設定済み／起動時に DEBUG ログで確認）

| 項目                 | 場所                                                                                        | 状態                              |
| -------------------- | ------------------------------------------------------------------------------------------- | --------------------------------- |
| Bundle ID            | `com.minato.beer-cheers`                                                                    | プロジェクト設定                  |
| Sign in with Apple   | [`beer_cheers.entitlements`](../beer_cheers/beer_cheers.entitlements)                       | Capability 済み                   |
| Google URL scheme    | [`beer-cheers-Info.plist`](../beer-cheers-Info.plist)                                       | `REVERSED_CLIENT_ID` と一致させる |
| GIDClientID          | 同上                                                                                        | Google Sign-In 用                 |
| 写真ライブラリ説明文 | Info.plist + Build Setting                                                                  | プロフィール画像用                |
| Associated Domains   | entitlements                                                                                | 招待 Universal Link               |
| 起動時チェック       | [`AuthXcodeConfigValidator`](../beer_cheers/Service/Account/AuthXcodeConfigValidator.swift) | DEBUG コンソールに ✓/⚠            |

Xcode での目視:

1. ターゲット **beer_cheers** → **Signing & Capabilities**
2. **Sign In with Apple** があること
3. **Associated Domains** に `applinks:beercheers.web.app` があること
4. 実機／シミュレータ起動 → Xcode コンソールで `[AuthConfig]` を確認

## Firebase コンソール（手動）

1. Authentication → Sign-in method で **Apple** と **Google** を有効化する。
2. **メール／パスワード** は無効のままでよい（アプリからは呼ばない）。

### Apple

1. Apple Developer で App ID `com.minato.beer-cheers` に **Sign In with Apple** を有効化（済みなら Identifiers でチェック確認のみ）。
2. Firebase の Apple プロバイダを有効化。iOS ネイティブのみなら Services ID は必須ではない。

### Google

1. Firebase の Google プロバイダを有効化。
2. ローカルの `GoogleService-Info.plist` の `REVERSED_CLIENT_ID` が Info.plist の URL scheme と一致していること（DEBUG ログでも検証）。

## アプリ側の流れ

1. 初回起動: 泡ローディング → [`StartFlowView`](../beer_cheers/View/Start/StartFlowView.swift)（ようこそ → 認証／ゲスト）
2. サインイン後: [`ProfileSetupView`](../beer_cheers/View/Account/ProfileSetupView.swift) でユーザー名・ニックネーム・画像が必須
3. 完了フラグ: [`StartFlowStore`](../beer_cheers/Model/Account/StartFlowStore.swift)
4. アカウントタブでは [`SocialAuthButtons`](../beer_cheers/View/Account/SocialAuthButtons.swift) で同じ IdP（編集画面からサインアウト／削除）

## ゲスト方針

合意どおり **ログインなしで Done**。スタートでゲストを選んでもルーム作成・参加・乾杯同期は使える。
