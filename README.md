# beer_cheers

スマホを振って乾杯する体験を共有する iOS アプリです。

## リポジトリの取得（公開リポジトリ）

このリポジトリは **GitHub 上で public** です。ソースと履歴を手元に取るには **`git clone`** を使ってください。

```bash
git clone https://github.com/mn329/beer_cheers.git
cd beer_cheers
```

`git init` は「まだ Git 管理されていない空のフォルダで、新しくリポジトリを作る」ときに使うコマンドです。このプロジェクトを取得する用途では **`git clone` が正しい**対応になります（`git init` だけでは GitHub 上の履歴やファイルは入りません）。

## 開発環境

- Xcode（プロジェクトは Xcode 26 系で作成）
- iOS 実機またはシミュレータ（モーションは実機推奨）

## ビルド

1. `beer_cheers.xcodeproj` を Xcode で開く
2. スキーム `beer_cheers` を選び、Run

## Firebase（任意）

リモート乾杯や Realtime Database を使う場合は、Firebase 用の plist（例: `GoogleService-Info.plist` またはリポジトリ内のカスタム名 plist）を用意し、`DATABASE_URL` など必要なキーを設定してください。  
**公開リポジトリに API キーを直書きした plist を push しない**よう注意してください（`.gitignore` で `GoogleService-Info.plist` を除外しています。チーム用の別経路で配布する想定です）。
