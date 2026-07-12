#!/usr/bin/env bash
# smithy SessionStart hook — inject a COMPACT digest (not the full skill:
# ~25 lines instead of ~110, the full router loads on demand) plus the
# project state head when smithy memory exists. Read-only, fail-silent.
set -u

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE="$ROOT/docs/smithy/STATE.md"

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

  if [ -f "$STATE" ]; then
    echo "[smithy] Project memory found (docs/smithy/):"
    head -n 40 "$STATE"
    echo "[smithy] Resume with /smithy — it recomputes position from docs/smithy/ledger.md, not recollection."
  fi
} 2>/dev/null

exit 0
