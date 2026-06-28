# cursor-timeline

Cursor 専用の macOS タイムラインアプリ。3日スライド、GCal 風の縦軸、repo 色ブロック + model 色ドット。

## 必要環境

- macOS 14+
- Cursor（ローカル DB にセッションが保存されていること）
- Swift 5.9+（Xcode 15 以降）

## ビルド & 起動

```bash
cd cursor-timeline

swift run                              # 開発（ターミナルから起動）
./build-app.sh && open CursorTimeline.app   # .app バンドル
swift test                               # テスト（実 DB 連携含む）
```

Toolbar 右の `b20260629…` がビルド番号。表示が古い場合は `./build-app.sh` 後に `killall CursorTimeline` してから再起動。

## データの場所

| 種類 | パス |
|------|------|
| Composer DB | `~/Library/Application Support/Cursor/User/globalStorage/state.vscdb` |
| Agent transcripts | `~/.cursor/projects/<slug>/agent-transcripts/` |
| workspace 情報 | `~/Library/Application Support/Cursor/User/workspaceStorage/` |

**外部送信なし。** すべてローカル読み取りのみ（ADR-003）。

## 使い方

| 操作 | 動作 |
|------|------|
| ← / → | 3日ずつスライド |
| Today | 一昨日・昨日・今日（今日が右端） |
| ↻ | DB / JSONL を再読み込み |
| ブロック tap | 右 Inspector に user プロンプト一覧 |

## v0.1 の制限

- **表示時間帯:** 08:00–23:00（深夜セッションは端でクリップ）
- **請求額:** プロンプト単位の $ 表示なし（v0.2 dashboard API 予定）
- **自動更新なし:** Refresh または再起動が必要
- **署名なし:** `./build-app.sh` で自分用 .app を生成（Developer ID / Notarization なし）
- **アーカイブ済みセッションも表示**（sidebar 非表示と無関係）
- **タイムゾーン:** Mac のシステム TZ に従う（日本なら JST）

## 読み込み方式（ADR-016）

1. セッション index 全件（bubble 本文なし）
2. 表示中 3 日分のメタだけフィルタ
3. その composer の user bubble のみ追加取得
4. Inspector tap 時に未ロード分を遅延取得

大きい DB（数 GB）でも全 bubble 一括読み込みはしない。

## Docs（SSOT）

| 優先 | ファイル | 役割 |
|------|----------|------|
| 1 | [docs/ADR.md](docs/ADR.md) | なぜそう決めたか |
| 2 | [docs/DESIGN.md](docs/DESIGN.md) | UI・データ設計 |
| 3 | [docs/TASKS.md](docs/TASKS.md) | 実装チェックリスト |

## Status

**v0.1** — 実データ接続済み。3日タイムライン + Inspector + 段階ロード。
