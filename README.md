# beer_cheers

## 概要

**beer_cheers** は、iPhone を振って「乾杯」を検知すると、ジョッキの絵文字・泡のエフェクト・乾杯音・ハプティクスが一斉に反応する **エア乾杯** 体験を届けるネイティブ **iOS** アプリです。  
Firebase **Realtime Database** と連携し、同じ「部屋」にいる端末同士で乾杯のタイミングを共有できる想定です（ローカルだけの演出も動作します）。

## 主な機能

| 区分 | 内容 |
|------|------|
| **衝撃検知** | `CoreMotion` の Device Motion（`userAcceleration`）で合成加速度が閾値を超えたら乾杯と判定。起動直後のノイズ無視、アーム期間中の閾値調整、クールダウンで誤検知・連打を抑制。 |
| **演出** | ビール絵文字のスプリングアニメーション、`Canvas` + `TimelineView` による泡パーティクル、「CHEERS!!」の短時間オーバーレイ。 |
| **フィードバック** | 乾杯音（`AVAudioPlayer` / `AVAudioSession`）、強めの衝撃ハプティクス＋細かい「シュワ」系ハプティクス。 |
| **リモート乾杯** | Realtime DB の `rooms/test_room/trigger` を監視し、値の更新で他端末由来の乾杯も再生。ローカル検知時はスロットル付きで同パスへ書き込み、自分の書き込みエコーの二重再生を抑制。 |
| **起動体験** | 泡用粒子配列をバックグラウンドで生成してから本画面を表示し、初回エフェクトのラグを軽減。 |

## 使用技術

- **言語・UI**: Swift 6、**SwiftUI**（`GeometryReader`、`Canvas`、`TimelineView` など）
- **状態管理**: **Observation**（`@Observable` / `@Bindable`）
- **モーション**: **CoreMotion**（`CMMotionManager`、Device Motion、`userAcceleration`）
- **音声**: **AVFoundation**（`AVAudioPlayer`、`AVAudioSession`、割り込み通知の扱い）
- **触覚**: **UIKit**（`UIImpactFeedbackGenerator`）
- **バックエンド連携**: **Firebase**（`FirebaseCore`、`FirebaseDatabase` / Realtime Database）  
  - Xcode プロジェクトには **Firebase Analytics** 製品もリンクされています（利用方針に合わせて無効化・削除可）。
- **並行性**: `async` / `await`、`Task`、`Task.detached`（粒子生成のオフメイン処理など）

## プロジェクト構成（ざっくり）

| ファイル | 役割 |
|----------|------|
| `beer_cheersApp.swift` | アプリエントリ、`FirebaseApp.configure`（標準 / カスタム名 plist 対応） |
| `AppEntryView` / `ContentView.swift` | 起動時の粒子プリロード、メイン画面レイアウト |
| `AirCheersViewModel.swift` | モーション監視、乾杯判定、音・ハプティクス、RTDB の読み書き、泡用状態 |
| `BeerFoamCanvasView.swift` | 泡の描画、`BeerFoamBudFactory` による粒子データ生成 |

## リポジトリの取得（公開リポジトリ）

このリポジトリは **GitHub 上で public** です。ソースと履歴を手元に取るには **`git clone`** を使ってください。

```bash
git clone https://github.com/mn329/beer_cheers.git
cd beer_cheers
```

`git init` は「まだ Git 管理されていない空のフォルダで、新しくリポジトリを作る」ときのコマンドです。このプロジェクトを取得する用途では **`git clone` が正しい**対応になります（`git init` だけでは GitHub 上の履歴やファイルは入りません）。

## 開発環境

- **Xcode**（プロジェクトは Xcode 26 系で作成）
- **iOS** 実機またはシミュレータ（**Device Motion は実機推奨**）

## ビルド

1. `beer_cheers.xcodeproj` を Xcode で開く  
2. スキーム **beer_cheers** を選び、**Run**

## Firebase（任意）

リモート乾杯や Realtime Database を使う場合は、Firebase 用の plist（例: `GoogleService-Info.plist`、またはアプリ内で試行されるカスタム名 plist）を用意し、**`DATABASE_URL`** など必要なキーを設定してください。

**公開リポジトリに API キーを直書きした plist を誤って push しない**よう注意してください。`.gitignore` では `GoogleService-Info.plist` を除外しています（チーム用の別経路で配布する想定）。  
リポジトリ同梱の `Firebase Project Settings - beercheers.plist` はサンプル／開発用の位置づけです。**本番用の秘密情報はコミットしない**運用を推奨します。
