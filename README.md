# cursor-timeline

Cursor 専用のセッションタイムライン — 3日スライド、GCal 風の縦軸、レポジトリ色・モデル色。

## Docs（SSOT）

| 優先 | ファイル | 役割 | 迷ったら |
|------|----------|------|----------|
| 1 | [docs/ADR.md](docs/ADR.md) | **なぜ**そう決めたか（判断の正） | 仕様と ADR が矛盾 → ADR を更新するか DESIGN を直す |
| 2 | [docs/DESIGN.md](docs/DESIGN.md) | **何を**作るか（UI・データ・**時系列フロー §4.5**） | 実装の詳細は DESIGN、Canvas ワイヤーは参考のみ |
| 3 | [docs/TASKS.md](docs/TASKS.md) | **いつ・順番**（実装チェックリスト） | 完了条件・Phase 順 |
| — | Cursor ローカル DB | **データ形式**の外部 SSOT | スキーマは Reader が実体に合わせる。差分は ADR/DESIGN に追記 |
| 実装後 | Swift コード + Tests | **動作**の SSOT | 挙動変更時はコードと docs をセットで更新 |

**要するに:** 設計フェーズの SSOT は **ADR → DESIGN → TASKS** の順。実装が始まったら **コードが動作の正**、docs はそれに追従する。

## Status

Phase 0 scaffold — SwiftPM + GRDB（Clippo 流儀）。`swift run` で空ウィンドウ。

## Build

```bash
swift run              # 開発中
./build-app.sh         # CursorTimeline.app
open CursorTimeline.app
```
