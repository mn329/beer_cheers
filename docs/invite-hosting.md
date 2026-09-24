# ルーム招待 URL（Firebase Hosting）

インストール済み端末では Universal Link / カスタムスキームでアプリが開き、未インストール時は本 Hosting のランディングが表示されます。App Store 公開後は `appStoreID` を入れると Store へ誘導できます。

## URL 形式

- HTTPS（主）: `https://{hostingHost}/join/{percent-encoded-roomID}`
- カスタムスキーム（補助）: `beercheers://join/{percent-encoded-roomID}`

## 初回セットアップ

1. Firebase CLI でログインし、プロジェクトを紐付ける。

```bash
cp .firebaserc.example .firebaserc
# default に Firebase プロジェクト ID を書く
firebase login
firebase use
```

2. Hosting 設定を確認する。

- [`firebase.json`](../firebase.json) — `"site": "beercheers"`（URL は `https://beercheers.web.app`）、`public` は `web/invite`
- [`web/invite/config.js`](../web/invite/config.js) — `hostingHost` / `appStoreID`
- [`web/invite/.well-known/apple-app-site-association`](../web/invite/.well-known/apple-app-site-association) — `appID` は `{TeamID}.com.minato.beer-cheers`

  プロジェクト ID は `beercheers-e9644` でも、招待用 Hosting サイト ID は **`beercheers`** を使う（アプリの `InviteLinkConfig.hostingHost` / Associated Domains と一致）。

3. アプリ側の [`InviteLinkConfig`](../beer_cheers/Model/Room/InviteLinkConfig.swift) の `hostingHost` が `beercheers.web.app` であること。Xcode の Associated Domains も `applinks:beercheers.web.app`。

4. デプロイする。

```bash
firebase deploy --only hosting
```

デプロイ後の確認 URL:

- https://beercheers.web.app
- https://beercheers.web.app/join/test
- https://beercheers.web.app/.well-known/apple-app-site-association

## App Store 公開後

1. `web/invite/config.js` の `appStoreID` に数値 ID を入れる。
2. `firebase deploy --only hosting` を再実行する。

## 動作確認のヒント

- インストール済み: Safari で HTTPS `/join/...` を開き、アプリ起動 → 参加確認を確認する。
- 未インストール / ブラウザ強制: リンクを長押しして「ブラウザで開く」→ ランディングと Store（または公開前案内）を確認する。
- AASA が効かない場合は CDN キャッシュや Associated Domains のタイプミスを疑う。`https://{host}/.well-known/apple-app-site-association` が JSON で返ることを確認する。
