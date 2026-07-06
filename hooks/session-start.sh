#!/usr/bin/env bash
# smithy SessionStart hook — if the project has smithy memory, surface the
# state head so the session knows work exists. Fail-silent, read-only,
# bounded output (≤45 lines).
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE="$ROOT/docs/smithy/STATE.md"

[ -f "$STATE" ] || exit 0

{
  echo "[smithy] Project memory found (docs/smithy/):"
  head -n 40 "$STATE"
  echo "[smithy] Resume with /smithy — it recomputes position from docs/smithy/ledger.md, not recollection."
} 2>/dev/null

exit 0
