# Tasks — cursor-timeline

実装タスク一覧。`docs/ADR.md` と `docs/DESIGN.md` に従う。

**v0.1 ゴール:** macOS 14+ で、ローカル Cursor データから 3 日縦タイムラインを表示できる .app

---

## 全体の受け入れ条件（v0.1 リリース）

**全部できたら v0.1 完了 🎉**

| # | 条件 | 確認方法 |
|---|------|----------|
| 1 | 同じ時間帯のセッションが横並び（重なりレイアウト） | 2件以上重なる日で列が分かれる |
| 2 | ブロック = repo 色、● = model 色 | 目視 + 凡例と一致 |
| 3 | ブロック選択 → Detail に user プロンプト一覧 | 時刻・モデル・本文が出る |
| 4 | ← → / Today / Refresh が動く | 日付範囲が変わる・最新に戻る・再読込 |
| 5 | 自分の `state.vscdb` + `agent-transcripts` で実データ表示 | 実際の Cursor セッションが見える |
| 6 | アーカイブ済みセッションも表示される | sidebar 非表示でもタイムラインに出る |
| 7 | 起動が実用速度（数秒目標） | 9GB 級 DB でも全 bubble 一括読みしない |

---

## Phase 0 — プロジェクト基盤（Clippo 流儀: SwiftPM）

- [ ] `Package.swift` — macOS 14 executable + GRDB + test target
- [ ] フォルダ構成 `Sources/CursorTimeline/{App,Features,Core}/`
- [ ] `Tests/CursorTimelineTests/`
- [ ] `build-app.sh` — `.app` バンドル化（Dock 表示、`Cursor Timeline` 表示名）
- [ ] 空の `ContentView` でビルド・実行確認

### 受け入れ条件

| 項目 | OK の状態 |
|------|-----------|
| ビルド | `swift build` **エラー 0** |
| 起動 | `swift run` または `open CursorTimeline.app` → **ウィンドウ**が出る |
| 構成 | `Sources/CursorTimeline/App|Features|Core` が存在 |
| 依存 | GRDB が `Package.swift` で解決される |
| テスト | `swift test` が pass |
| .app | `./build-app.sh` → `CursorTimeline.app` が生成される |

**Verify:** `swift run` で「Cursor Timeline」ウィンドウが起動する

---

## Phase 1 — Core Models & Layout

- [ ] `TimelineSession`, `PromptEvent`, `ModelFamily`, `SessionSource` 定義
- [ ] `ThreeDayWindow`（3日スライド計算・今日=右端・一昨日〜今日）
- [ ] `OverlapLayout.compute(sessions:)` 実装
- [ ] `OverlapLayoutTests`: 3件完全重なり / 2件部分重なり / 重なりなし

### 受け入れ条件

| 項目 | OK の状態 |
|------|-----------|
| モデル | 型がコンパイルでき、Preview / テストでインスタンス化できる |
| ThreeDayWindow | **Today** → `[一昨日, 昨日, 今日]`、今日が **index 2（右端）** |
| ThreeDayWindow | `goPrev()` / `goNext()` で **±3 日**スライド |
| OverlapLayout | 重ならない → 全幅 1 列 |
| OverlapLayout | 3件同時刻 → **3 列に等分** |
| OverlapLayout | 部分重なり → 正しい column / totalColumns |
| テスト | `OverlapLayoutTests` **全 pass** |

**Verify:** テスト全 pass

---

## Phase 2 — Readers（ローカルデータ）

- [ ] `CursorPaths` — 標準パス解決（`Application Support/Cursor/...`）
- [ ] `SessionMeta` — 軽量インデックス型（ADR-016 段1）
- [ ] `CursorDatabaseReader`
  - [ ] `fetchSessionIndex()` — `composer.composerHeaders` + `composerData:*` メタのみ（**アーカイブ除外しない**）
  - [ ] `fetchUserBubbles(composerIds:)` — 指定 ID の user bubble のみ
- [ ] DB ロック時の temp コピー fallback
- [ ] `AgentTranscriptReader` — JSONL parse, user messages
- [ ] `RepoResolver` — workspace path → repoId / label
- [ ] `ModelNormalizer` — raw model string → `ModelFamily`
- [ ] `TimelineMerger` — composer + agent 統合・**1ブロックマージ**・時刻 confidence 付与
- [ ] subagents パスはスキップ（v0.1）

### 受け入れ条件

| 項目 | OK の状態 |
|------|-----------|
| CursorPaths | 標準 macOS パスが解決される（DB 無しでもパス文字列は正） |
| fetchSessionIndex | 実 DB で **全セッション件数**が取れる（bubble 本文は読まない） |
| fetchSessionIndex | `isArchived == true` のセッションも **含まれる** |
| fetchUserBubbles | 指定 composerId の **user プロンプトだけ**返る（type=1） |
| fetchUserBubbles | **全 composer 一括**は呼ばない設計 |
| AgentTranscriptReader | `role == user` のみ。`subagents/` はスキップ |
| RepoResolver | 同一 repo → 安定した `repoId` |
| ModelNormalizer | `claude-4.6-opus-high` → `.opus` 等 |
| TimelineMerger | composer + agent が **1 TimelineSession** にマージできる |
| TimelineMerger | 時刻に `TimestampConfidence` が付く |
| DB ロック | readonly 失敗時 → temp コピーで読める |
| 性能 | `fetchSessionIndex` が **数十秒以内**（全 bubble parse しない） |

**Verify:** fixture テスト or CLI で `TimelineSession[]` が取れる。アーカイブ 1 件以上含むこと。

---

## Phase 3 — TimelineStore

- [ ] `@Observable class TimelineStore`
- [ ] `reload() async` — SessionIndex 全件（段1）→ `loadWindow()`（段2–3）
- [ ] `loadWindow() async` — ±3日ナビ時はメタ再利用 + bubble 差分取得
- [ ] `loadPrompts(for:)` — Inspector 用遅延ロード（段4）
- [ ] `window: ThreeDayWindow` + `goPrev()` / `goNext()` / `goToday()`
- [ ] `sessionsInWindow` フィルタ（メタの start/end と 3 日ウィンドウの重なり）
- [ ] `selection: TimelineSession?`
- [ ] `loadedComposerIds` で bubble 二重読み込み防止

### 受け入れ条件

| 項目 | OK の状態 |
|------|-----------|
| reload | SessionMeta **全件** → 現在ウィンドウの TimelineSession が構築される |
| loadWindow | ±3日で **sessionIndex は再読みしない** |
| loadWindow | 新ウィンドウに入ったセッションの bubble **だけ**追加取得 |
| loadedComposerIds | 同じ composerId を **2 回 bubble 読みしない** |
| goToday | 一昨日・昨日・今日に戻る |
| sessionsInWindow | 3 日外のセッションは **sessions に含まれない** |
| loadPrompts | 段3未ロードの選択時だけ DB 再アクセス |
| Preview | Store 経由で直近 3 日の **件数 > 0**（実 DB 環境） |

**Verify:** Store 経由で「直近3日」のセッション件数が Preview で確認できる

---

## Phase 4 — SwiftUI（タイムライン UI）

- [x] `TimeGutterView` — 08:00–22:00
- [x] `DayColumnView` — 日ヘッダー + グリッド線
- [x] `SessionBlockView` — repo 色、重なり frame、title
- [x] `PromptDotView` — model 色 ●、tooltip
- [x] `ThreeDayTimelineView` — 3列 + gutter、横スクロール不要（min 280 × 3）
- [x] `SessionInspectorView` — repo, 時刻, prompts 一覧
- [x] `TimelineToolbar` — ← → Today Refresh
- [x] `LegendView` — repo / model 凡例
- [x] `ContentView` — `HSplitView` 組み立て

### 受け入れ条件

| 項目 | OK の状態 |
|------|-----------|
| レイアウト | **3 日列 + 左 time gutter + 右 Inspector** |
| 時間軸 | **08:00–22:00** 表示 |
| 今日 | 右端列が **accent 強調** |
| SessionBlock | repo 色背景 + 左ボーダー + title |
| PromptDot | ブロック右端、model 色 ●、時刻位置 |
| 重なり | OverlapLayout の column が **幅等分**で反映 |
| Toolbar | ← → Today Refresh が Store に繋がる |
| Inspector | **user プロンプトのみ**（時刻・モデル・本文） |
| 凡例 | repo / model の色が一覧 |
| データ | **モックデータ**でワイヤー通り（実 DB 不要） |

**Verify:** モックデータでワイヤー通りの見た目

---

## Phase 5 — 実データ接続 & 仕上げ

- [x] TimelineStore を実 Reader に接続
- [ ] 自分の環境で Fri 重なり・Sun 2列が再現されることを確認
- [x] 空状態・読み込み中・DB 不在のエラー UI
- [x] README 更新（ビルド手順、データパス、制限事項）
- [x] `.gitignore` に `xcuserdata/`, `DerivedData/` 等

### 受け入れ条件

| 項目 | OK の状態 |
|------|-----------|
| 実データ | モックなしで **自分の Cursor セッション**が表示 |
| 重なり | 実データで **2 列以上**の日が再現できる |
| Refresh | Cursor で新プロンプト後 → Refresh で **増える** |
| アーカイブ | sidebar 非表示セッションも **タイムラインに出る** |
| 空状態 | セッション 0 件 → 日本語メッセージ |
| 読込中 | reload 中 → ローディング表示 |
| DB 不在 | Cursor 未インストール等 → 日本語エラー |
| README | ビルド手順・データパス・v0.1 制限が書いてある |
| 起動速度 | 大きい DB でも **全 bubble 一括読みで固まらない** |

**Verify:** 実際の Cursor 利用後に Refresh でセッションが増える

---

## v0.2 — Backlog（スコープ外・順不同）

- [ ] `FileWatcher` — DB / JSONL 変更で自動 reload
- [ ] Hooks JSONL ingest（`beforeSubmitPrompt`）
- [ ] Dashboard usage API — プロンプト時刻突合 + Detail に $
- [ ] `MenuBarExtra` — 今日のセッション数
- [ ] ログイン時起動
- [ ] Settings — repo 色カスタム、時間帯 0–24
- [ ] `.cursor/skills/cursor-timeline` — 「timeline 開いて」
- [ ] Developer ID 署名 + DMG（友人配布）

---

## ユーザー確認ポイント

**方針:** 自動テストで足りるところはユーザー確認しない。  
**人間が見るべきは 3 回** — データ正しさ → UI 見た目 → 実データ E2E。

| # | タイミング | 必須? | 何を見せる | ユーザーが OK を出すこと |
|---|-----------|-------|-----------|------------------------|
| **U1** | Phase 2 完了後 | **必須** | CLI / Preview で **自分の DB** から取ったセッション一覧（JSON or 表） | 件数・タイトル・時刻・repo が **Cursor の記憶と合う**。アーカイブ済みも **含まれている** |
| **U2** | Phase 4 完了後 | **必須** | **モックデータ**入りアプリ（まだ実 DB 未接続） | 3日レイアウト・repo 色・model ●・重なり・Inspector・日本語 UI が **ワイヤー意図と合う** |
| **U3** | Phase 5 完了後 | **必須** | **実データ**入りアプリ | v0.1 全体 AC（上表 7 項目）を **実機で全部満たす** |

### 各 Phase のユーザー確認（要否）

| Phase | ユーザー確認 | 理由 |
|-------|-------------|------|
| 0 土台 | **スキップ可** | 空ウィンドウ — 開発者が Cmd+R 確認で足りる |
| 1 モデル | **スキップ可** | ユニットテストが正本 |
| 2 Reader | **U1 必須** | データ解釈を間違えると後戻り最大。UI 前に正す |
| 3 Store | **U1.5 推奨** | 起動速度・3日件数だけサッと見る（1〜2分）。合わなければ Phase 5 前に修正 |
| 4 UI | **U2 必須** | 見た目の合意。実データ接続前に UX を固定 |
| 5 仕上げ | **U3 必須** | v0.1 リリース判定 |

### U1 で具体的に確認する項目（チェックリスト）

実装者がターミナル出力 or 簡易 Preview を見せ、ユーザーが目視:

- [ ] 直近 3 日のセッション件数が **だいたい合ってる**
- [ ] 知ってるセッション名 / 最初のプロンプトが **一致**
- [ ] repo 名（フォルダ名）が **正しい**
- [ ] **アーカイブしたセッション**が一覧にいる
- [ ] composer + agent が **1 ブロックにマージ**されてる（重複してない）
- [ ] 時刻が **大きくズレてない**（数分〜数十分は許容、日付違いは NG）
- [ ] `fetchSessionIndex` が **数十秒以内**（固まらない）

**NG なら:** Phase 3 以降に進まず Reader / Merger を直す。

### U2 で具体的に確認する項目

モックデータで以下を操作してもらう:

- [ ] 一昨日・昨日・今日、**今日が右**
- [ ] 重なりブロックが **横に並ぶ**
- [ ] ブロック色 = repo、● = model
- [ ] ブロック tap → Inspector にプロンプト
- [ ] ← → Today の **ラベル・配置**が自然
- [ ] 08:00–22:00 の **密度**（窮屈 / スカスカ）

**NG なら:** Phase 5 前に UI 定数（幅・色・時間帯）を直す。

### U3 で具体的に確認する項目

自分の Mac + 自分の Cursor データで:

- [ ] U2 の UI が **実データでも破綻しない**
- [ ] Cursor で新プロンプト → Refresh → **増える**
- [ ] アーカイブセッションが **タイムラインに出る**
- [ ] 起動 **数秒**（コーヒー待ち不要）
- [ ] 空 / エラー時の **日本語メッセージ**が分かりやすい

**NG なら:** v0.1 未完了。Phase 5 の残タスク or ADR 見直し。

### 確認の進め方（おすすめ）

```
Phase 2 → U1（15分）→ OK なら Phase 3–4
Phase 4 → U2（10分）→ OK なら Phase 5
Phase 5 → U3（20分）→ OK なら v0.1 完了 🎉
```

Screenshots でも可。U1 は **ターミナル出力 10 行 + 知ってるセッション 1 件の中身** だけ見せれば十分。

---

## リスクと対策

| リスク | 対策 |
|--------|------|
| Cursor DB スキーマ変更 | Reader をバージョン分岐、fixture テスト |
| agent-transcripts に時刻なし | Merger で confidence 表示、Hooks は v0.2 |
| 大量セッションで遅い | ADR-016: メタ全件 + bubble はウィンドウ分のみ。v0.2 で SwiftData キャッシュ |
| DB ロック | temp コピー fallback |

---

## 実装順（推奨）

```
Phase 0 → 1 → 2 → 3 → 4（モック）→ 5（実データ）
```

Phase 1 の `OverlapLayout` は UI より先に固める。Phase 2 は Phase 4 のモック表示と並行可能。
