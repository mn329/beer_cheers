# struct と class（beercheers 学習メモ）

学習日: 2026-07-27  
教材の中心: `AirCheersViewModel`（class）と `UserAccountProfile`（struct）

---

## 1. 定義

| | struct | class |
|---|---|---|
| 種類 | 値型（Value Type） | 参照型（Reference Type） |
| 渡したとき | **コピー**される（別の箱） | **同じ実体**を共有する |
| 片方を変えると | 他方は変わらない | 他方からも同じ変更が見える |

### 「コピー」とは

中身が同じでも、**メモリ上の別の置き場所**が作られること。

- struct: メモのコピーを渡す
- class: 同じ共有ドキュメントへのリンクを渡す

この話は「乾杯相手の別ユーザー」ではなく、**同じアプリ内の変数・画面どうし**の話。

---

## 2. beercheers での使い分け

### class にするもの（所有者・実体）

| 型 | ファイル | 理由 |
|---|---|---|
| `AirCheersViewModel` | `ViewModel/AirCheersViewModel.swift` | 複数画面で同じ状態（roomID・監視・演出）を共有する |
| `AccountViewModel` | `ViewModel/Account/AccountViewModel.swift` | プロフィールや roomID の最新を握る |
| `ClinkAudioPlayer` など Service | `Service/Audio/ClinkAudioPlayer.swift` など | 音声プレイヤー等の**実体と寿命**を1つで管理する |

### struct にするもの（データの形・画面）

| 型 | ファイル | 理由 |
|---|---|---|
| `UserAccountProfile` | `Model/Account/UserAccount.swift` | データの定義そのもの。同じ実体として持ち回る必要がない |
| `FoamBud` | `Model/BeerFoamParticleModel.swift` | 泡1個分のパラメータ（独立した値） |
| `CheersView` / `RootTabView` など | `View/` / `App/` | SwiftUI の画面は基本 struct |

### 目安

> 迷ったら struct。同じ実体の共有や寿命管理が必要なら class。

> struct のデータを複数画面で揃えたいときは、class の所有者（ViewModel）の中に置く。

---

## 3. コード上の流れ（共有の実例）

```text
AppEntryView
  @State private var viewModel = AirCheersViewModel()   ← 1つ作る（class）
       ↓
RootTabView(cheersViewModel: viewModel)                 ← 同じ参照を渡す
       ↓
CheersView(viewModel: cheersViewModel)                  ← さらに渡す
       ↓
onAppear  → startMonitoring()  → audio.activate()       ← 始める
onDisappear → stopMonitoring() → audio.deactivate()     ← 片付ける
```

- View（`AppEntryView`, `RootTabView`, `CheersView`）は **struct**
- 共有している本体は **`AirCheersViewModel`（class）**
- `RootTabView` 自体を class にする必要はない

### 所有者のイメージ

```text
AccountViewModel（class・所有者）
  └── profile: UserAccountProfile（struct・データの形）
        └── displayName など
```

- 最新の `displayName` を握るのは `AccountViewModel`
- `UserAccountProfile` は中身のデータの定義
- `AccountView` は所有者から借りて表示する側

---

## 4. ViewModel を struct にしたらどうなるか

各画面が **別コピー** を持つ。

```text
画面A のコピー: roomID を更新
画面B のコピー: 古い roomID のまま（自動では揃わない）
```

揃えるには、更新後の値を親に戻して全画面に配り直す必要がある（面倒で抜けやすい）。

class なら、更新は1か所でよく、他画面は同じ実体を見ているだけ。

---

## 5. `UserAccountProfile` を class にしたら？

動くが、この用途では不利が多い。

警戒点: **別変数に入れても同じ実体を指し、意図しない更新が起きること**

例（下書き）:

```text
var draft = viewModel.profile
draft.displayName = "太郎"
```

- struct → `draft` だけ変わる（本体は無事）
- class → 本体も変わってしまうことがある（キャンセルしづらい）

だからデータの定義は struct、共有は ViewModel（class）経由が安全。

---

## 6. 「寿命」とは（Service が class な理由）

### 寿命の意味

オブジェクトが生まれてから消えるまでの期間。  
開始・利用・片付けを **同じ1つの実体** に対して行う必要があるものに、寿命という見方が効く。

`ClinkAudioPlayer` の例:

1. 生まれる … `ClinkAudioPlayer()`
2. 生きているあいだ … 同じ実体で `play()` / 中断監視（電話などで音が止まるへの対応）
3. 片付ける … `deactivate()`（監視の解除など）
4. 消える … 参照がなくなったら回収

`CheersView` → `AirCheersViewModel` では:

- 始める: `startMonitoring()` → `audio.activate()`
- 片付ける: `stopMonitoring()` → `audio.deactivate()`

同様に `MotionImpactDetector` も `start` / `stop` があり、センサー監視の寿命を1つの class で握っている。

### 寿命があるものを struct にするとどうなるか

渡すたびにコピーされやすいので、**「始めた箱」と「使う／片付ける箱」が分裂**し得る。

```text
【class（今）】
同じ1つ
  activate() で監視を開始
  play() で同じプレイヤーを使う
  deactivate() で同じ監視を外す

【struct にした場合】
コピーA: activate() した（監視を付けた）
コピーB: play() する（別の箱かも）
コピーC: deactivate() する（A の監視を外せない）
```

起こり得る不具合:

1. **片付け漏れ** … 中断監視や AudioSession まわりが残る
2. **音が出ない／挙動がおかしい** … 準備したプレイヤーと再生するプレイヤーが別物
3. **責任の所在が不明** … どのコピーが「本物」か分からなくなる

| | class（今） | struct にした場合 |
|---|---|---|
| activate / play / deactivate | 同じ実体 | コピーで分裂しやすい |
| 寿命 | 1か所で握れる | 誰が本物か分かりにくい |

補足: struct でも「絶対にコピーせず、いつも同じ `var` だけ触る」と工夫すれば動かす道はあるが、壊れやすく、音声・センサーのような寿命付きリソースは **class が自然**。

### 一言で覚える

> 寿命もの（音声・センサー）は、開始・利用・片付けを同じ1つの実体に対して行うため class。

---

## 7. 自分の言葉で言う（面接・説明用）

1. struct は渡すとコピーされ、class は同じ実体を共有する。
2. ViewModel を class にする理由は、複数画面が同じ実体を共有し、片方の更新が他方にも見えるようにするため。
3. `UserAccountProfile` のようなものは、データの定義そのものなので struct にする。共有は ViewModel が担う。
4. beercheers では `AirCheersViewModel` を `AppEntryView` で1つ作り、`RootTabView` へ渡している。
5. 音声やセンサーのように開始・片付けがあるものは、同じ実体で寿命を握るため class にする。

---

## 8. よくある誤解

| 誤解 | 修正 |
|---|---|
| 変わる値は全部 class | 変更可否ではなく、同じ実体を共有するかで選ぶ |
| 1画面で完結する情報＝struct | 画面数では決まらない。同じ実体として持ち回るかで選ぶ。複数画面で揃えるなら struct のデータを class の ViewModel に載せる |
| 複数画面で使うなら全部 class | データの形は struct、所有者だけ class でよい |
| class になるのは ViewModel だけ | Service（音声・センサー等）も class になり得る |
| 寿命ものでも struct でよいのでは | コピーで「開始した実体」と「片付けする実体」が割れ、漏れや不具合になりやすい |
| struct は共有できない | 単体をばらばらに持つと揃わない。所有者（class）の中に置けば共有できる |
| コピー＝ユーザー間の複製 | アプリ内メモリ上の別の箱の話 |

---

## 関連ファイル

- `beer_cheers/App/AppEntryView.swift`
- `beer_cheers/App/RootTabView.swift`
- `beer_cheers/View/Cheers/CheersView.swift`
- `beer_cheers/ViewModel/AirCheersViewModel.swift`
- `beer_cheers/ViewModel/Account/AccountViewModel.swift`
- `beer_cheers/Model/Account/UserAccount.swift`
- `beer_cheers/Service/Audio/ClinkAudioPlayer.swift`
- `beer_cheers/Service/Motion/MotionImpactDetector.swift`
