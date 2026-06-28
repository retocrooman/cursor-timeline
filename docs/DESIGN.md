# Design — cursor-timeline

SwiftUI ネイティブ macOS アプリの設計書。UI ワイヤー（3日縦タイムライン）とデータ層の対応を定義する。

## 1. プロダクト概要

**目的:** Cursor のセッションを、Google Calendar weekly 風の **縦型タイムライン** で 3 日分表示する。

**ユーザーが答えられること:**
- いつ・どの repo で・どんなプロンプトを送ったか
- 同じ時間帯に並行していたセッションは何か

**v0.1 で答えないこと:**
- プロンプトごとの正確な請求額（→ v0.2 dashboard API）

---

## 2. 画面構成

```
┌─────────────────────────────────────────────────────────────┐
│ Toolbar:  ←  |  Jun 26 – 28, 2026  |  →  |  Today  |  ↻   │
├───────────────────────────────────────┬─────────────────────┤
│  Time │  Fri 26  │  Sat 27  │  Sun 28  │  Detail             │
│ 08:00 │          │          │          │                     │
│ 09:00 │  [block] │          │          │  Repo swatch        │
│  ...  │  [●●]    │  [block] │ [b][b]   │  Prompts list       │
│ 22:00 │          │          │          │  (model dot color)  │
├───────────────────────────────────────┴─────────────────────┤
│ Legend: Repo colors  |  Model dot colors                    │
└─────────────────────────────────────────────────────────────┘
```

### 定数

| 項目 | 値 |
|------|-----|
| 表示日数 | 3 |
| 初期ウィンドウ | 一昨日・昨日・今日（今日 = 右端） |
| 日列 min 幅 | 280 pt |
| 表示時間帯（初期） | 08:00 – 22:00 |
| スクロール拡張（v0.2） | 00:00 – 24:00 |
| ナビステップ | ±3 日 |
| UI 言語 | 日本語固定（v0.1） |
| アプリ名 | Cursor Timeline |
| データ読込 | メタ全件 → 3日フィルタ → bubble はウィンドウ分のみ（ADR-016） |

### インタラクション

| 操作 | 動作 |
|------|------|
| セッションブロック tap | Detail にプロンプト一覧 |
| ● hover | tooltip: `HH:mm · Model · prompt 先頭` |
| ← / → | ウィンドウを 3 日スライド |
| Today | **一昨日・昨日・今日**（今日が右端）へジャンプ |
| ↻ Refresh | DB / JSONL を全件再読み込み |

---

## 3. ビジュアルルール

### 3.1 セッションブロック（repo 色）

- 背景: repo 色 16% 不透明（近似）
- 左ボーダー: 4 pt solid repo 色
- 高さ: `startAt` – `endAt` を時間軸にマッピング
- 重なり: 同一日の overlap cluster 内で列分割（`OverlapLayout`）

**repo ID の決定（優先順）:**
1. `workspace.json` の folder URI → git remote `origin` URL
2. フォルダ名（`~/.cursor/projects/Users-...` のデコード）
3. フォールバック: `unknown`

**worktree:** 同一 repo として扱い、色・repoId は共有。パス差は区別しない（ADR-019）。

**empty-window（ホーム）:** Cursor プロジェクト未指定の workspace ID。`repoId = "empty-window"`、表示ラベル **「ホーム」**。除外しない（ADR-022）。

**空 Untitled:** プロンプト 0 件の `Untitled` セッションはタイムライン非表示（ADR-022）。index メタは保持。

**セッションタイトル:** `composerData.name` → なければ最初のユーザープロンプト先頭（ADR-014）。

**色割当:** `hash(repoId) % palette.count` で安定色（Settings で上書き可・v0.2）。

### 3.2 プロンプト ●（model 色）

- ブロック右端、縦位置 = プロンプト時刻
- 直径 7 pt
- 色は model ファミリーで固定マップ:

| Model ファミリー | 色（仮） |
|------------------|----------|
| Opus | Purple |
| Sonnet | Blue |
| Composer | Green |
| GPT | Orange |
| その他 | Gray |

モデル名は `bubble` / transcript から正規化（`claude-4.6-opus-high` → `opus`）。

### 3.3 今日の列

- 日付ヘッダーを accent 色で強調

---

## 4. データモデル

```swift
/// ADR-016 段1: bubble 本文なしの軽量インデックス
struct SessionMeta: Identifiable {
    let id: String              // composerId
    let repoId: String
    let repoLabel: String
    let title: String
    let startAt: Date           // composerData / 先頭 bubble から推定
    let endAt: Date             // lastUpdatedAt 等
    let messageCount: Int       // fullConversationHeadersOnly 件数
    let source: SessionSource
}

struct TimelineSession: Identifiable {
    let id: String              // composerId or transcript UUID
    let repoId: String
    let repoLabel: String       // 表示用 short name
    let title: String
    let startAt: Date
    let endAt: Date
    let source: SessionSource   // composer | agentTranscript | merged
    let prompts: [PromptEvent]
}

struct PromptEvent: Identifiable {
    let id: String
    let sessionId: String
    let timestamp: Date
    let text: String
    let model: ModelFamily
    let confidence: TimestampConfidence  // high | medium | low
}

enum TimestampConfidence {
    case high    // createdAt from SQLite
    case medium  // interpolated / hooks
    case low     // mtime fallback
}
```

```swift
struct ThreeDayWindow {
    var start: Date   // 00:00 local, day 1
    var days: [Date]  // 3 elements
}
```

---

## 4.5 データの流れ（時系列）

Cursor 上の操作からアプリ表示まで、**いつ・どこに・何が正本か**を時系列で示す。

### A. ユーザーが Cursor でプロンプトを送ったとき

```
あなたがプロンプト送信
        │
        ▼
┌───────────────────────────────────────────────────────────┐
│ Cursor がローカルに書き込む（外部送信なし）                  │
├───────────────────────────────────────────────────────────┤
│ ① globalStorage/state.vscdb                                │
│    composerData:{composerId}  … セッション名・メッセージ順 │
│    bubbleId:{composerId}:{id} … 各メッセージ本文・時刻     │
│                                                           │
│ ② workspaceStorage/.../state.vscdb（Cursor ≤2.6）        │
│    または global composer.composerHeaders（Cursor 3.0+）   │
│    … サイドバー用一覧メタ（isArchived 等）                 │
│                                                           │
│ ③ ~/.cursor/projects/.../agent-transcripts/{uuid}.jsonl   │
│    … Agent セッション時のみ（user 行に本文、時刻は弱い）    │
└───────────────────────────────────────────────────────────┘
```

**この時点の正本（フィールド別）:**

| 知りたいこと | 正本 |
|-------------|------|
| プロンプト本文 | `bubbleId`（user / type=1）または JSONL の user 行 |
| 送信時刻 | `bubble.createdAt`（最優先。ADR-008） |
| セッション名 | `composerData.name` |
| どの repo？ | `workspaceIdentifier` / workspace パス |
| モデル | bubble の model 情報 |

### B. Cursor でセッションをアーカイブしたとき

```
アーカイブ操作
        │
        ▼
composer.composerHeaders（一覧）の isArchived = true
        │
        ├─ composerData / bubbleId … 削除されない ✅
        ├─ agent-transcripts/*.jsonl … そのまま ✅
        └─ Cursor サイドバー … 非表示になるだけ

完全削除（purge） … 別操作。v0.1 では扱わない
```

**cursor-timeline の方針:** `isArchived` で **除外しない**。`fetchSessionIndex()` は sidebar フラグを無視し、`composerData` / bubble から読めるセッションはすべて対象。

### C. Cursor Timeline アプリ起動〜表示（ADR-016）

```
起動 / Refresh
    │
    ├─[段1] fetchSessionIndex()
    │       composer.composerHeaders + composerData:*
    │       → SessionMeta[]（全セッション・メタのみ、~秒台）
    │
    ├─[段2] filterSessions(in: ThreeDayWindow)
    │       start/end が 3 日と重なるセッションだけ
    │
    ├─[段3] fetchUserBubbles(段2の composerIds)
    │       + AgentTranscriptReader（同上 ID）
    │       → TimelineMerger → TimelineSession[]（プロンプト込み）
    │
    └─ UI 描画（OverlapLayout → ブロック + ●）

±3 日ナビ
    │
    ├─ 段1 は再実行しない（SessionMeta 再利用）
    ├─ 段2 → 段3（新しく見えるセッションの bubble だけ追加取得）
    └─ loadedComposerIds で二重読み込み防止

Inspector でブロック選択
    │
    └─[段4] 未ロードなら loadPrompts(for: 1件)
            既に段3で読んでいればそのまま表示
```

### D. アプリ内の正本（マージ後）

```
CursorDatabaseReader ─┐
                      ├→ TimelineMerger → TimelineSession + [PromptEvent]
AgentTranscriptReader ┘         ↑
                                │
                         UI / Inspector が読む正本
```

| レイヤ | 役割 | SSOT か |
|--------|------|---------|
| Cursor ローカル DB / JSONL | 生データ | 外部 SSOT（形式の正） |
| `SessionMeta` | 全セッション一覧・日付フィルタ用 | アプリ内・軽量索引 |
| `TimelineSession` | 表示・Inspector 用 | **アプリ内 SSOT** |
| Canvas ワイヤー | UI 参考 | ❌ |

### E. 設計ドキュメントの優先順位（プロジェクト SSOT）

```
ADR.md  →  DESIGN.md  →  TASKS.md  →  （実装後）Swift コード + Tests
 なぜ         何を作る      いつやる           動作の正
```

---

## 5. データソースと Reader

### 5.1 パス（macOS）

| データ | パス |
|--------|------|
| Global DB | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` |
| Workspace DB | `~/Library/Application Support/Cursor/User/workspaceStorage/<hash>/state.vscdb` |
| Agent transcripts | `~/.cursor/projects/<project>/agent-transcripts/<uuid>/<uuid>.jsonl` |

### 5.2 CursorDatabaseReader

- GRDB readonly
- **API を 2 本に分ける**（ADR-016）:
  1. `fetchSessionIndex()` — 全セッション **メタのみ**
     - 優先: global `ItemTable` の `composer.composerHeaders`
     - フォールバック / 補完: `cursorDiskKV` の `composerData:*`（headers に無い孤児セッション）
     - 抽出: `composerId`, `name`, `createdAt`, `lastUpdatedAt`, `workspaceIdentifier`, `fullConversationHeadersOnly` の件数（bubble 本文は読まない）
     - **`isArchived` は無視**（除外しない）
  2. `fetchUserBubbles(composerIds:)` — 指定 ID の **user bubble のみ**
     - `cursorDiskKV` where `bubbleId:<composerId>:*`
     - `type == 1` のみ parse。assistant / tool bubble は v0.1 では読まない
     - 抽出: `createdAt`, user text, model 名

**ロック対策:**
1. 通常: readonly 接続
2. 失敗時: `state.vscdb` を temp にコピーして読む（v0.1）
3. v0.2: FSEvents で debounce 再読み込み

### 5.2.1 ロードパイプライン（ADR-016）

```
起動 / Refresh
  → fetchSessionIndex()          … 全セッション メタ（~秒台）
  → filterSessions(in: window)   … 3日と時間重なり
  → fetchUserBubbles(ids)        … ウィンドウ内のみ
  → AgentTranscriptReader        … 同上 composerId
  → TimelineMerger               … TimelineSession 生成

±3日ナビ
  → filterSessions(in: window)   … メタは再利用
  → fetchUserBubbles(新規 ids)   … 未ロード分だけ

Inspector 選択
  → 未ロードなら fetchUserBubbles([id]) + transcript
```

### 5.3 AgentTranscriptReader

- JSONL 1 行 = 1 message
- `role == user` のみ PromptEvent 候補
- セッション境界 = 1 ファイル
- **`subagents/` 配下は v0.1 ではスキップ**
- 時刻は ADR-008 の優先順位で `TimelineMerger` が付与
- 低信頼タイムスタンプは Inspector に「時刻: 推定」と表示（ADR-018）

### 5.4 TimelineMerger

1. composer セッションを master timeline に
2. agent transcript を composerId / 時間近接 / workspace でリンク
3. **同一作業と判定できれば 1 ブロックにマージ**（ADR-015）
4. 同一セッション重複は `sessionId` で dedupe
5. 日付範囲外は UI フィルタ時に除外（**SessionIndex は全件保持**、bubble はウィンドウ分のみ）

**マージ判定（v0.1 仮ルール — 実装時に fixture で検証）:**
1. `composerId` が transcript パス / bubble と一致 → マージ
2. 同一 `repoId` かつ `startAt` が ±15 分以内 → マージ候補（プロンプト時刻で紐付け）
3. それ以外は別ブロック

**セッション時刻:**
- `startAt` = 最初の user prompt の `createdAt`（または補完時刻）
- `endAt` = 最後の bubble / prompt の時刻（+0分。v0.1 はバッファなし）

---

## 6. アプリアーキテクチャ

```
CursorTimelineApp
└── ContentView
    ├── TimelineToolbar
    ├── HSplitView
    │   ├── ThreeDayTimelineView
    │   │   ├── TimeGutterView
    │   │   └── ForEach(day) { DayColumnView }
    │   │         └── SessionBlockView (OverlapLayout frame)
    │   └── SessionInspectorView
    └── LegendView

@Observable TimelineStore
├── sessionIndex: [SessionMeta]   // 全セッション メタ（ADR-016 段1）
├── window: ThreeDayWindow
├── sessions: [TimelineSession]   // ウィンドウ内・プロンプト込み（段3）
├── selection: TimelineSession?
├── loadedComposerIds: Set<String>
└── reload() async / loadWindow() async
```

### TimelineStore

- 起動 / Refresh: `reload()` → **SessionIndex 全件** → `loadWindow()`（段 2–3）
- `window` 変更（±3日）: `loadWindow()` のみ（メタ再利用、bubble は差分取得）
- Inspector 選択: 未ロードセッションは `loadPrompts(for:)` で段 4
- v0.2: `FileWatcher` が `reload()` を debounce 呼び出し

### SessionInspectorView（Detail）

v0.1 は **ユーザープロンプト一覧のみ**（時刻・モデル色・本文）。AI 返答・tool call は v0.2。

---

## 7. OverlapLayout

**入力:** 同一日の `[TimelineSession]`（start/end 付き）

**出力:** `[SessionId: (column: Int, totalColumns: Int)]`

**アルゴリズム:**
1. start 昇順、duration 降順でソート
2. overlap cluster に分割（次のイベント start < clusterEnd）
3. cluster 内で greedy column 割当
4. `totalColumns = column 数`

ユニットテスト必須: 3 件重なり・部分重なり・非重なり。

---

## 8. プロジェクト構成（SwiftPM — Clippo 流儀）

```
cursor-timeline/
├── Package.swift
├── build-app.sh
├── Sources/
│   ├── CursorTimeline/Core/          # CursorTimelineCore ライブラリ（テスト可）
│   │   ├── Models/
│   │   └── Layout/
│   └── CursorTimeline/App/           # @main executable
│       ├── CursorTimelineApp.swift
│       └── ContentView.swift
├── Tests/CursorTimelineTests/
│   ├── OverlapLayoutTests.swift
│   └── ThreeDayWindowTests.swift
└── docs/
```

**ビルド:**
- 開発: `swift run`
- 日常: `./build-app.sh` → `open CursorTimeline.app`

**依存（SPM）:**
- GRDB

> Xcode プロジェクトは使わない。Clippo（`retocrooman/Clippo`）と同じ SwiftPM + `build-app.sh` パターン。

---

## 9. 非機能要件

| 項目 | v0.1 |
|------|------|
| 起動 | 数秒以内に直近 3 日が表示（目標）。メタ全件 + ウィンドウ分 bubble のみ（ADR-016） |
| オフライン | 完全ローカル |
| プライバシー | データは外部送信しない |
| アクセシビリティ | VoiceOver でセッション title + 時刻（最低限） |

---

## 10. ワイヤー参照

初期 UI 検討は Cursor Canvas ワイヤーで実施済み（3日・repo 色・model ●・重なり）。実装時は本 DESIGN を正とする。
