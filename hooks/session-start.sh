#!/usr/bin/env bash
# smithy SessionStart hook — runs when a session starts. It adds a SHORT
# digest to the context (~25 lines, not the full ~110-line router skill, which
# loads only when needed), plus the top of STATE.md when smithy memory exists.
# Read-only. On any error it prints nothing and exits 0.
set -u

SMITHY_PATHS_FAST=1   # session start must not be slow; path rules 1-4 are pure bash
# shellcheck source=../scripts/paths.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" && pwd)/paths.sh" 2>/dev/null || SMITHY_MEM=""
# In a lane (e.g. a session opened inside a smithy parallel worktree), the
# LANE's state is the one that describes this session's work.
STATE="${SMITHY_STATE_DIR:+$SMITHY_STATE_DIR/STATE.md}"

{
  cat <<'DIGEST'
<smithy-digest>
Smithy (full dev pipeline) is installed. Routing (invoke the smithy:using-smithy skill for the full router + red-flags):
  build end-to-end→smithy | research/spec→assay | plan→blueprint | implement→forge | TDD/bugfix→jig | review diff→inspect | ship-ready panel→guild | test personas→commission | design→pattern | design review→burnish | quick known fix→strike | debug/RCA→anneal | test all→temper | unit→ring-test | QA→wield | load→proof | perf→hone | session end→handover | model routing→calibrate
Iron rules:
  1. Process first: a feature ("build X") enters at assay/smithy, never directly at forge; a small known change or review/QA fix-up goes to strike.
  2. RCA before fix (anneal); ledger + git log outrank recollection; evidence before assertion.
  3. Git/destructive ops are hook-guarded, and every smithy subagent dispatch is routing-guarded (model + effort forced to config) — a block or a [smithy-route-guard] correction is the system working; report it, never work around it. Routing changes go through /smithy:calibrate, never through the dispatch call.
  4. Every skill starts with scripts/start.sh and works on its own (missing spec/plan → a fallback, never a stop). Read each reference file (creed/memory-card/dispatch/envelope) ONCE per session; re-read only after compaction.
  5. Lookup tools (memory, code-graph, docs) are optional helpers: read-only use is free; anything that sends/creates/updates/deletes needs the user's yes (creed §10).
</smithy-digest>
DIGEST

  if [ -n "$STATE" ] && [ -f "$STATE" ]; then
    echo "[smithy] Project memory found at $SMITHY_MEM ($SMITHY_MEM_SOURCE):"
    head -n 40 "$STATE"
    echo "[smithy] \$SMITHY_MEM=$SMITHY_MEM — every smithy path in the skills is relative to it."
    if [ -n "${SMITHY_LANE:-}" ]; then
      echo "[smithy] STATE LANE '$SMITHY_LANE' active ($SMITHY_LANE_SOURCE) — the state above is this LANE's."
      echo "[smithy] Your ledger writes go to lanes/$SMITHY_LANE/; merge them with scripts/lane.sh merge $SMITHY_LANE when the work lands."
    fi
    echo "[smithy] Resume with /smithy — it recomputes position from the ledger, not recollection."
  fi

  # An unmerged lane holds events that are NOT in the project ledger. Say so at
  # session start, or a resume will quietly miss work that already happened.
  if [ -z "${SMITHY_LANE:-}" ] && [ -n "${SMITHY_MEM:-}" ] && [ -d "$SMITHY_MEM/lanes" ]; then
    stale=""
    for d in "$SMITHY_MEM"/lanes/*; do
      [ -d "$d" ] || continue
      [ "$(basename "$d")" = ".merged" ] && continue
      stale="$stale $(basename "$d")"
    done
    [ -n "$stale" ] && \
      echo "[smithy] UNMERGED state lanes:$stale — their events are NOT in the project ledger. Read them (SMITHY_LANE=<name> scripts/ledger.sh tail) before judging progress, then merge or abandon."
  fi
} 2>/dev/null

exit 0
