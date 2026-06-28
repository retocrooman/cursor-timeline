# Architecture Decision Records — cursor-timeline

このドキュメントは cursor-timeline の主要な設計判断（ADR）を記録する。実装前に合意した前提を固定し、後から「なぜそうしたか」を追えるようにする。

## ADR-001: SwiftUI ネイティブ macOS アプリ

**Status:** Accepted

**Context:** 3日縦タイムライン（GCal 風）、重なりレイアウト、repo / model 色分け、ローカルデータの継続監視が必要。

**Decision:** メイン UI は SwiftUI ネイティブ macOS アプリとする。Tauri / Electron / localhost Web / VS Code 拡張は採用しない。

**Rationale:**
- Mac 常駐・メニューバー・ファイル監視と相性が良い
- `~/Library/.../Cursor` と `~/.cursor` へのローカルアクセスが自然
- タイムライン UI を 1 か所で完結できる

**Consequences:**
- Swift Package Manager + `build-app.sh` の保守が必要（Clippo と同じ流儀）
- Windows / Linux はスコープ外

---

## ADR-002: 3日スライドウィンドウ（Weekly ではない）

**Status:** Accepted

**Context:** ユーザーは weekly より「直近 3 日」を常に見たい。日列はある程度ワイドに取りたい。

**Decision:** 横軸は常に 3 日。ナビゲーションは ±3 日スライド。Day 単体タブは v0.1 では作らない。

**Rationale:**
- 情報密度と可読性のバランス
- ワイヤーで合意済みの UX

**Consequences:**
- 週次ヒートマップ等は v0.2 以降

---

## ADR-003: v0.1 はローカルデータのみ

**Status:** Accepted

**Context:** Cursor ダッシュボード API はリクエスト単位の token / $ は正確だがプロンプト本文と session ID がない。ローカル SQLite はプロンプトと時刻はあるが token はほぼ空。

**Decision:** v0.1 は以下のみを読む。
- `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb`
- `~/Library/Application Support/Cursor/User/workspaceStorage/*/state.vscdb`（必要に応じて）
- `~/.cursor/projects/*/agent-transcripts/*.jsonl`

Dashboard usage API による $ 突合は **v0.2**。

**Rationale:**
- プロダクトの核は「いつ・どの repo で・どんなプロンプトか」の可視化
- 非公式 API 依存を MVP から外せる

**Consequences:**
- v0.1 にコスト表示は出さない（または推定のみ・非表示）

---

## ADR-004: セッション色 = リポジトリ、ドット色 = モデル

**Status:** Accepted

**Context:** Composer / Agent の出所より、ユーザーが追いたいのは「どのプロジェクトで」「どのモデルで」。

**Decision:**
- セッションブロック: 背景 + 左ボーダー = **repo**（workspace path / git remote から安定 ID）
- プロンプト ●: **model** ごとの色

Composer vs Agent の区別は色ではなく、Inspector のメタデータで示す（v0.1）。

**Rationale:**
- ワイヤーで合意済み
- token heat strip は不要（ADR-005）

---

## ADR-005: Token heat strip なし

**Status:** Accepted

**Decision:** タイムライン上に token / $ のヒートストリップは載せない。

**Rationale:** UI をシンプルに保ち、コストは v0.2 の dashboard 突合で Detail に出す。

---

## ADR-006: 重なりレイアウトは greedy column

**Status:** Accepted

**Context:** 同一日・同一時間帯に複数セッションが存在する。

**Decision:** Google Calendar と同様、overlap cluster 内で greedy column 割当 → 列幅を等分。

**Rationale:**
- 実装が単純でテスト可能
- ワイヤーで検証済み

**Consequences:**
- `OverlapLayout` を Core に切り出し、ユニットテスト必須

---

## ADR-007: SQLite アクセスは GRDB（readonly）

**Status:** Accepted

**Decision:** `state.vscdb` 読み取りに [GRDB.swift](https://github.com/groue/GRDB.swift) を使用。接続は read-only。

**Rationale:**
- Swift エコシステムで実績がある
- WAL 併用時の読み取りパターンが確立している

**Consequences:**
- Cursor 起動中のロック時はリトライ or コピー読み（DESIGN.md 参照）

---

## ADR-008: agent-transcripts の時刻は補完する

**Status:** Accepted

**Context:** `agent-transcripts/*.jsonl` のメッセージ行に時刻フィールドがない。ファイル mtime のみでは精度が低い。

**Decision:** マージ優先順位:
1. `bubbleId` / composer の `createdAt`（SQLite）
2. Hooks JSONL（v0.2・任意）
3. JSONL 行順 + セッション開始時刻の補間
4. 最終手段: transcript ファイル mtime

**Rationale:** Agent セッションを落とさず、可能な限り正確な時刻軸を維持する。

---

## ADR-009: Hooks は v0.2（任意インストール）

**Status:** Accepted

**Decision:** `beforeSubmitPrompt` 等の Hooks 連携は v0.1 スコープ外。v0.2 で JSONL ingest を追加。

**Rationale:** v0.1 はローカル既存データだけで価値を出す。

---

## ADR-010: 配布は個人利用（署名なし .app）

**Status:** Accepted

**Decision:** v0.1 は Developer ID 署名・Notarization なし。ローカル `./build-app.sh` で `.app` を生成し自分で使う。

**Rationale:** 配布ゴールが個人利用。署名コストと手続きを MVP から除外。

---

## ADR-011: 最低 macOS 14 Sonoma

**Status:** Accepted

**Decision:** `MACOSX_DEPLOYMENT_TARGET = 14.0`

**Rationale:** SwiftUI の現行 API を広く使いつつ、利用者の環境をカバー。

---

## ADR-012: Cursor Skill は v0.2

**Status:** Accepted

**Decision:** `.cursor/skills/cursor-timeline` はアプリ MVP 後。役割は「timeline を開く / 期間指定でエクスポート」などのショートカット。

**Rationale:** 表示本体はアプリ。Skill は補助。

---

## ADR-013: 3日ウィンドウは「一昨日・昨日・今日」（今日が右端）

**Status:** Accepted

**Decision:** 起動時および Today ボタンは、**一昨日・昨日・今日**の 3 日を表示する（今日が右端）。

**Rationale:** 直近の作業履歴を見る用途に合う。未来の日は表示しない。

---

## ADR-014: セッションタイトルは Composer 名優先

**Status:** Accepted

**Decision:** ブロック上のタイトルは Cursor のセッション名（`composerData.name`）。空なら最初のユーザープロンプト先頭。

---

## ADR-015: Composer + Agent は 1 ブロックにマージ

**Status:** Accepted

**Decision:** 同一作業と判定できる Composer（DB）と Agent（JSONL）は **1 つの `TimelineSession`** にまとめる。

**Rationale:** タイムラインの重複を減らし、ユーザーが追いやすくする。

---

## ADR-016: 段階的ロード（メタ全件・bubble はウィンドウ分）

**Status:** Accepted（2026-06-28 改定）

**Context:** 個人環境の `state.vscdb` は **数 GB〜10GB 超**・セッション数千件になりうる。`composerData` + 全 `bubbleId` をナイーブに読むと **数分** かかる（計測例: メタ 3630 件 ~5s、1 セッション bubble 262 件 ~23s）。起動のたびに全 bubble を読む設計は不可。

**Decision:** 起動・Refresh は **4 段階** で読む。sidebar の `isArchived` は **フィルタしない**（アーカイブ後も `composerData` / `bubbleId` は残る）。

| 段 | いつ | 読むもの | 保持 |
|----|------|----------|------|
| 1 | 起動 / Refresh | 全セッション **メタのみ**（`composer.composerHeaders` および/または `composerData:*` から id, name, createdAt, lastUpdatedAt, workspace, start/end 推定） | メモリ上の `SessionIndex` |
| 2 | ウィンドウ確定 | 表示中 3 日と **時間が重なる** セッションだけ抽出 | `sessionsInWindow`（プロンプト未ロード可） |
| 3 | タイムライン描画 | 段 2 のセッションについて **user bubble のみ**（`type == 1`）+ 対応 `agent-transcripts` | `TimelineSession` + `PromptEvent` |
| 4 | Inspector 選択 | 未ロードならその 1 セッションのプロンプト全文を遅延ロード | `selection` 用キャッシュ |

**ナビゲーション（±3 日）:** 段 1 は再実行しない。段 2 → 3 を現在ウィンドウに対して再実行。未ロードセッションの bubble のみ追加取得。

**Rationale:**
- 起動体感 **数秒** を目標にできる（DESIGN §9）
- 全期間スライド可能（メタは常にメモリ保持）
- アーカイブ済みセッションもタイムラインに出せる

**Consequences:**
- `SessionIndex`（軽量メタ）と `TimelineSession`（表示用）を分ける
- `CursorDatabaseReader` に `fetchSessionIndex()` / `fetchUserBubbles(composerIds:)` を分離
- v0.2: SwiftData 等でメタ + mtime キャッシュ（ADR 未決定表参照）

---

## ADR-017: subagent は v0.1 非表示

**Status:** Accepted

**Decision:** `agent-transcripts/*/subagents/*.jsonl` は v0.1 では読まない。

---

## ADR-018: 低信頼タイムスタンプは Inspector のみ表示

**Status:** Accepted

**Decision:** `TimestampConfidence.low/medium` はブロック見た目は変えず、Detail に「時刻: 推定」等を表示。

---

## ADR-019: worktree は区別しない

**Status:** Accepted

**Decision:** 同一 git repo の worktree は **同じ repo 色・同じ repoId**。パス差は Inspector のメタデータのみ（v0.1）。

---

## ADR-020: UI 言語は日本語固定

**Status:** Accepted

**Decision:** v0.1 のラベル・ボタン・エラー文言は日本語固定。

---

## ADR-021: アプリ表示名は「Cursor Timeline」

**Status:** Accepted

**Decision:** Dock / メニューバー / About の表示名は **Cursor Timeline**。

---

## ADR-022: empty-window は「ホーム」、空 Untitled は非表示

**Status:** Accepted（2026-06-28）

**Context:** Cursor の `empty-window` workspace はプロジェクト未指定のホーム画面セッション。`Untitled` は名前未設定の空 composer が大量にインデックスに含まれる。

**Decision:**
1. **`empty-window`** — **除外しない**。`repoId = "empty-window"`（安定）、表示ラベルは **「ホーム」**。Cursor ホーム画面での作業としてタイムラインに出す。
2. **`Untitled`** — **プロンプト 0 件のセッションのみ非表示**。名前が Untitled でも user プロンプトがあれば表示（タイトルは ADR-014 通り先頭プロンプトにフォールバック）。
3. フィルタは **表示層**（`SessionVisibility`）。`fetchSessionIndex()` の全件メタは保持（ADR-016）。

**Rationale:** ノイズを減らしつつ、ホームでの実セッション（cursor-timeline 等）は落とさない。

---

## 未決定（v0.2 以降で再検討）

| 項目 | 候補 |
|------|------|
| Menu Bar 常駐 | `MenuBarExtra` |
| ログイン時起動 | `SMAppService` |
| Dashboard API 突合 | 非公式 `get-filtered-usage-events` or Admin API |
| SwiftData キャッシュ | 大量セッション時の起動高速化 |
