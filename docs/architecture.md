# アーキテクチャ（MVVM + Repository）

beer_cheers の層分けと、パフォーマンス方針のメモ。

## 層

```
View → ViewModel → Repository（データの読み書き）
                 → Device Service（センサー・音・触覚・演出）
```

| 層 | 役割 | 例 |
|----|------|-----|
| **View** | 表示と操作の受け渡し | `CheersView`, `RoomView`, `AccountView` |
| **ViewModel** | 画面用の状態・ユースケースのオーケストレーション | `AirCheersViewModel`, `RoomViewModel`, `AccountViewModel` |
| **Repository** | Firebase / ローカル永続化の窓口（パスや SDK 詳細を隠す） | `RoomRepository`, `UserProfileRepository`, `ProfileAvatarRepository` |
| **Device Service** | 端末機能の寿命管理（start/stop） | `MotionImpactDetector`, `ClinkAudioPlayer`, `CheersHapticsPlayer` |

**やらないこと**: UseCase / Domain 層の大量追加（この規模の MVP では過剰）。

## Repository と Service の違い

- **Repository** … 読む・書く・監視する（データの倉庫）
- **Device Service** … 動かす・止める（端末の機械）

どちらも ViewModel の下位。View から Firebase や CoreMotion を直接呼ばない。

## パフォーマンス方針

1. **推測より計測**（実機の体感 → 必要なら Instruments）
2. 常時ループを疑う（例: 泡の `TimelineView` はバースト後に休止）
3. ネットワーク再取得を減らす（アバター画像のメモリキャッシュ）
4. 巨大 View の分割は可読性と SwiftUI 再評価範囲の縮小の両方に効く
5. 根拠のない `drawingGroup()` や過剰な抽象化はしない
