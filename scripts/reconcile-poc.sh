#!/usr/bin/env bash
# Team usage CSV × ローカル bubble の突合 PoC
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CSV="${1:-$HOME/Downloads/team-usage-events-11563757-2026-06-28.csv}"

if [[ ! -f "$CSV" ]]; then
  echo "CSV not found: $CSV" >&2
  echo "Usage: $0 [path/to/team-usage-events.csv]" >&2
  exit 1
fi

export USAGE_CSV_PATH="$CSV"
cd "$ROOT"
swift test --filter UsageReconciliationPoCTests.testPoCAgainstLocalCSVAndDatabase 2>&1 \
  | rg -v '^Test (Case|Suite|run )' \
  | rg -v '^(◇|↳|✔|Executed|Testing|Build complete|Building|\[)' \
  || true
