# Firebase Storage（プロフィール画像）

サインイン後の必須プロフィール画像は `avatars/{uid}.jpg` に保存します。

## コンソール手順

1. Firebase コンソール → **Storage** を有効化（未作成なら作成）。
2. Rules に以下を Publish（MVP 向け。本番前に締め直すこと）。

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // ファイル名全体が1セグメント（例: testUser123.jpg）
    match /avatars/{imageId} {
      allow read: if true;
      allow write: if request.auth != null
                   && imageId == request.auth.uid + '.jpg'
                   && request.resource.size < 5 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

読み取りはメンバー一覧で他端末からも見るため公開。書き込みは本人の UID パスのみ。

## プロフィール（Realtime Database）

再ログインで復元するため、メタデータは次に保存します。

- パス: `users/{uid}/profile`
- 内容: `username` / `nickname` / `avatarURL` / `avatarEmoji`

Realtime Database ルールに `users` を含めて Publish してください（[`database.rules.json`](../database.rules.json) 参照）。

```
"users": {
  "$uid": {
    ".read": "auth != null && auth.uid == $uid",
    ".write": "auth != null && auth.uid == $uid"
  }
}
```

## アプリ側

- [`ProfileAvatarRepository`](../beer_cheers/Repository/ProfileAvatarRepository.swift)
- 必須入力 UI: [`ProfileSetupView`](../beer_cheers/View/Account/ProfileSetupView.swift)
- ルーム表示: ニックネーム（大）＋ `@username`（小）＋画像
