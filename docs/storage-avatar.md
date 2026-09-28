# Firebase Storage（プロフィール画像）

サインイン後の必須プロフィール画像は `avatars/{uid}.jpg` に保存します。

## ルールの管理とデプロイ

Storage / Realtime Database のルールはリポジトリで管理し、Firebase CLI でデプロイします（コンソールで直接編集しない）。

- Storage: [`storage.rules`](../storage.rules)
- Realtime Database: [`database.rules.json`](../database.rules.json)
- 対応付け: [`firebase.json`](../firebase.json) の `storage` / `database`

```sh
firebase deploy --only database,storage
```

### Storage ルールの方針

- 取得（`get`）は公開: メンバー一覧で他端末からも画像を表示するため。
- 一覧（`list`）は不可: `avatars/` を列挙して全ユーザーの画像を集められないようにするため。
- 書き込み・削除は本人の `avatars/{uid}.jpg` のみ。アプリは 512px の JPEG を上げるため、サイズ上限は 1MB。

## プロフィール（Realtime Database）

再ログインで復元するため、メタデータは次に保存します。

- パス: `users/{uid}/profile`
- 内容: `username` / `nickname` / `avatarURL` / `avatarEmoji` / `updatedAt`
- 読み書きは本人のみ。フィールドの型と文字数を `.validate` で制限しています。

## ルーム（Realtime Database）

- `rooms/{roomID}` 単位でのみ読み書きできます。`rooms` 直下の一覧取得は不可（ルーム名とパスワードを列挙させないため）。
- `meta` / `members/{memberID}` / `trigger` 以外の子と、想定外のフィールドは拒否します。
- 文字数上限はアプリの入力上限より余裕を持たせています（既存クライアントの書き込みを拒否しないため）。

### 既知の制約（技術的負債）

- ルーム名を知っていれば、そのルームの `meta.password`（平文）も読めます。パスワード照合がクライアント側のため。
- 認証なしで書き込めるため、ルーム名を知る第三者による書き込みは防げません。App Check の導入で緩和できます。

## アプリ側

- [`ProfileAvatarRepository`](../beer_cheers/Repository/ProfileAvatarRepository.swift)
- 必須入力 UI: [`ProfileSetupView`](../beer_cheers/View/Account/ProfileSetupView.swift)
- ルーム表示: ニックネーム（大）＋ `@username`（小）＋画像
