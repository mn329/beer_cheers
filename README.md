# beer_cheers

## 概要

**beer_cheers** は、iPhone を振って「乾杯」を検知すると、ジョッキの絵文字・泡のエフェクト・乾杯音・ハプティクスが一斉に反応する **エア乾杯** 体験を届けるネイティブ **iOS** アプリです。  
Firebase **Realtime Database** と連携し、同じ「部屋」にいる端末同士で乾杯のタイミングを共有できます（ローカルだけの演出も動作します）。  
下部タブで **乾杯** と **アカウント**（プロフィール・ルーム切替・認証）を切り替えます。

## 主な機能

| 区分               | 内容                                                                                                                                                                         |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **衝撃検知**       | `CoreMotion` の Device Motion（`userAcceleration`）で合成加速度が閾値を超えたら乾杯と判定。起動直後のノイズ無視、アーム期間中の閾値調整、クールダウンで誤検知・連打を抑制。  |
| **演出**           | ビール絵文字のスプリングアニメーション、`Canvas` + `TimelineView` による泡パーティクル、「CHEERS!!」の短時間オーバーレイ。                                                   |
| **フィードバック** | 乾杯音（`AVAudioPlayer` / `AVAudioSession`）、強めの衝撃ハプティクス＋細かい「シュワ」系ハプティクス。                                                                       |
| **リモート乾杯**   | Realtime DB の `rooms/{roomID}/trigger` を監視し、値の更新で他端末由来の乾杯も再生。ローカル検知時はスロットル付きで同パスへ書き込み、自分の書き込みエコーの二重再生を抑制。 |
| **アカウント**     | 表示名・アイコン、Sign in with Apple / Google（Firebase Auth）、ゲスト利用可、アプリ情報。                                                                                 |
| **起動体験**       | 泡用粒子の事前生成のあと、初回はようこそ／認証スタート。2 回目以降は本画面へ。                                                                                             |

## 使用技術

- **言語・UI**: Swift 6、**SwiftUI**（`GeometryReader`、`Canvas`、`TimelineView`、浮遊タブバーなど）
- **状態管理**: **Observation**（`@Observable` / `@Bindable`）
- **モーション**: **CoreMotion**（`CMMotionManager`、Device Motion、`userAcceleration`）
- **音声**: **AVFoundation**（`AVAudioPlayer`、`AVAudioSession`、割り込み通知の扱い）
- **触覚**: **UIKit**（`UIImpactFeedbackGenerator`）
- **バックエンド連携**: **Firebase**（`FirebaseCore`、`FirebaseDatabase` / Realtime Database、`FirebaseAuth`）
  - Xcode プロジェクトには **Firebase Analytics** 製品もリンクされています（利用方針に合わせて無効化・削除可）。
- **並行性**: `async` / `await`、`Task`、`Task.detached`（粒子生成のオフメイン処理など）

## プロジェクト構成

```
beer_cheers/
├── App/                 # 起動・Tab
├── View/                # Cheers / Room / Account / Start / Common
├── ViewModel/           # 画面オーケストレーター
├── Repository/          # Firebase 等のデータ窓口（Room / Profile / Avatar）
├── Service/             # 端末機能（Motion / Audio / Haptics / Remote sync / Auth）
└── Model/               # データ型
```

詳細は [`docs/architecture.md`](docs/architecture.md)。

| 主なファイル                                   | 役割                                                       |
| ---------------------------------------------- | ---------------------------------------------------------- |
| `App/beer_cheersApp.swift`                     | エントリ、Firebase / Google Sign-In 初期化、タブバー見た目 |
| `App/AppEntryView.swift`                       | 泡の事前生成 → 初回 `StartFlowView` / 以降 `RootTabView`   |
| `View/Start/StartFlowView.swift`               | ようこそ → Apple / Google / ゲスト                         |
| `App/RootTabView.swift`                        | 下部 TabView、リモート監視・部屋連携                       |
| `ViewModel/AirCheersViewModel.swift`           | Motion / Audio / Haptics / Remote / Effects の束ね         |
| `Repository/RoomRepository.swift`              | ルーム meta / members の RTDB 操作                         |
| `Repository/RoomSessionStore.swift`            | ルーム ID / メンバー ID のローカル永続化                   |
| `Repository/UserProfileRepository.swift`       | プロフィールの RTDB 保存・復元                             |
| `Service/Cheers/CheersEffectsController.swift` | ジョッキ・泡・キャプション演出                             |
| `View/Cheers/CheersView.swift`                 | 乾杯メイン UI                                              |
| `ViewModel/Account/AccountViewModel.swift`     | プロフィール・認証 UI 状態                                 |

## リポジトリの取得（公開リポジトリ）

このリポジトリは **GitHub 上で public** です。ソースと履歴を手元に取るには **`git clone`** を使ってください。

```bash
git clone https://github.com/mn329/beer_cheers.git
cd beer_cheers
```

## 開発環境

- **Xcode**（プロジェクトは Xcode 26 系で作成）
- **iOS** 実機またはシミュレータ（**Device Motion は実機推奨**）

## ビルド

1. `beer_cheers.xcodeproj` を Xcode で開く
2. スキーム **beer_cheers** を選び、**Run**

### Apple Watch（乾杯エフェクトのみ）

Watch ターゲット **beer_cheers Watch App** が同梱されています。

- Watch 画面: タップでジョッキ演出 + ハプティクス
- ペアリング済み iPhone が同じ共有ルームにいれば、Watch の乾杯が iPhone 経由でリモート同期されます（WatchConnectivity）
- ルーム作成・参加・ホスト操作は **iPhone のみ**

初回は Xcode → Settings → Platforms（または Components）から **watchOS 26** を入れてください。未導入だと iPhone スキームのビルドも「embedded Apple Watch app」で止まります。

## Firebase（任意）

リモート乾杯や Realtime Database / Auth を使う場合は、Firebase コンソールから取得した **GoogleService-Info.plist**（または同形式の plist）を用意してください。

1. `beer_cheers/Firebase Project Settings - beercheers.plist.example` をコピーし、同フォルダに **`Firebase Project Settings - beercheers.plist`** という名前で保存する（拡張子 `.example` を外す）。
2. 各キーを Firebase の設定値で置き換える。`DATABASE_URL` は Realtime Database の URL を設定する。
3. **Realtime Database のルール**を公開する。未設定や `auth != null` のみだと、未サインインの実機で `Permission Denied` になります。

   Firebase コンソール → **Realtime Database** → **Rules** を開き、リポジトリ直下の [`database.rules.json`](database.rules.json) **全文**を貼り付けて **Publish** してください。  
   （`meta` / `trigger` だけでなく、メンバー一覧用の **`members`** も必要です。以前のルールのままだとメンバーの読み書きが拒否されます。）

   製品MVP向けの暫定ルールです。本番前に認証必須へ締めてください。

### ルーム招待 URL（Hosting）

共有リンクは `https://{host}/join/{roomID}`（Universal Link）。未インストール時は Hosting ランディングを表示し、App Store 公開後は Store へ誘導できます。

手順は [`docs/invite-hosting.md`](docs/invite-hosting.md) を参照してください。

### Sign in with Apple / Google

手順は [`docs/social-auth.md`](docs/social-auth.md) を参照してください。サインイン後はユーザー名・ニックネーム・画像が必須です（画像は Storage。手順は [`docs/storage-avatar.md`](docs/storage-avatar.md)）。

`.gitignore` により、上記のローカル plist や `GoogleService-Info.plist` は **Git に含まれません**。チームでは安全な経路で配布するか、各自がコンソールから取得してください。
