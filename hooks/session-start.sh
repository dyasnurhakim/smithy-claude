#!/usr/bin/env bash
# smithy SessionStart hook — inject a COMPACT digest (not the full skill:
# ~25 lines instead of ~110, the full router loads on demand) plus the
# project state head when smithy memory exists. Read-only, fail-silent.
set -u

SMITHY_PATHS_FAST=1   # session start must not stall; rules 1-4 are pure bash
# shellcheck source=../scripts/paths.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/paths.sh" 2>/dev/null || SMITHY_MEM=""
STATE="${SMITHY_MEM:+$SMITHY_MEM/STATE.md}"

{
  cat <<'DIGEST'
<smithy-digest>
Smithy (full dev pipeline) is installed. Routing (invoke the smithy:using-smithy skill for the full router + red-flags):
  build end-to-end→smithy | research/spec→assay | plan→blueprint | implement→forge | TDD/bugfix→jig | review diff→inspect | ship-ready panel→guild | test personas→commission | design→pattern | design review→burnish | quick known fix→strike | debug/RCA→anneal | test all→temper | unit→ring-test | QA→wield | load→proof | perf→hone | session end→handover | model routing→calibrate
Iron rules:
  1. Process first: "build X" enters at assay/smithy, never directly at forge — even when it seems clear.
  2. RCA before fix (anneal); ledger + git log outrank recollection; evidence before assertion.
  3. Git/destructive ops are hook-guarded — a block is the system working; report it, never work around it.
  4. Read each smithy reference file (creed/memory/dispatch/envelope) ONCE per session; skip re-reads unless post-compaction.
  5. Use companion tools named in the user's CLAUDE.md/rules (memory, code-graph, docs); never assume unlisted ones.
</smithy-digest>
DIGEST

  if [ -n "$STATE" ] && [ -f "$STATE" ]; then
    echo "[smithy] Project memory found at $SMITHY_MEM ($SMITHY_MEM_SOURCE):"
    head -n 40 "$STATE"
    echo "[smithy] \$SMITHY_MEM=$SMITHY_MEM — every smithy path in the skills is relative to it."
    echo "[smithy] Resume with /smithy — it recomputes position from \$SMITHY_MEM/ledger.md, not recollection."
  fi
} 2>/dev/null

exit 0
