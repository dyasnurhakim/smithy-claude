#!/usr/bin/env bash
# ledger.sh — single writer/reader for the smithy per-project event ledger.
#
# Usage:
#   ledger.sh append <phase> <job> <unit> <status> <artifact-path>
#   ledger.sh tail [n]          (default 20; lane events merged over project's)
#   ledger.sh last <phase>      (most recent line for a phase, merged view)
#   ledger.sh where             which file is appended, which files are read
#
# Line format (pipe-delimited, one line per event):
#   2026-07-06T10:22Z | forge | user-auth | task-2 | DONE | jobs/user-auth/reports/task-2-impl.md
set -euo pipefail

# Resolve via paths.sh: one ledger per PROJECT, anchored on the MAIN worktree.
# (Deriving it from --show-toplevel used to split the ledger during a parallel
# forge batch — each linked worktree would have written its own.)
#
# LANES refine that: when a lane is active, APPENDS go to the lane's own
# ledger so concurrent units never interleave, but READS return the lane's
# events merged over the project's in timestamp order. A controller resuming
# inside a lane after compaction must see the whole history, not just the
# slice its lane happened to produce. scripts/lane.sh merge folds the lane
# ledger into the project one permanently.
# shellcheck source=./paths.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/paths.sh"
LEDGER="$SMITHY_STATE_DIR/ledger.md"
MAIN_LEDGER="$SMITHY_MEM/ledger.md"

# The read view: project events + lane events, timestamp-ordered. Identical to
# the merged file lane.sh will eventually write, so resume decisions taken
# inside a lane match the ones taken after it lands.
# Only ever cats files that exist: this script runs under `set -e -o pipefail`,
# where a `cat` of a not-yet-created ledger would abort the whole call.
ledger_view() {
  local files=""
  [ -f "$MAIN_LEDGER" ] && files="$MAIN_LEDGER"
  if [ "$LEDGER" != "$MAIN_LEDGER" ] && [ -f "$LEDGER" ]; then
    files="$files $LEDGER"
  fi
  [ -n "$files" ] || return 0
  # shellcheck disable=SC2086
  cat $files | sort -s -k1,1
}
VALID_STATUSES="STARTED DONE DONE_WITH_CONCERNS NEEDS_CONTEXT BLOCKED APPROVED REJECTED PASS FAIL PARTIAL"

case "${1:-}" in
  append)
    [ $# -eq 6 ] || { echo "usage: ledger.sh append <phase> <job> <unit> <status> <artifact>" >&2; exit 2; }
    phase="$2"; job="$3"; unit="$4"; status="$5"; artifact="$6"
    case " $VALID_STATUSES " in
      *" $status "*) ;;
      *) echo "ledger.sh: invalid status '$status' (valid: $VALID_STATUSES)" >&2; exit 2 ;;
    esac
    mkdir -p "$(dirname "$LEDGER")"
    ts="$(date -u +%Y-%m-%dT%H:%MZ)"
    printf '%s | %s | %s | %s | %s | %s\n' "$ts" "$phase" "$job" "$unit" "$status" "$artifact" >> "$LEDGER"
    ;;
  tail)
    n="${2:-20}"
    if [ -f "$LEDGER" ] || [ -f "$MAIN_LEDGER" ]; then
      ledger_view | tail -n "$n"
    else
      echo "(no ledger at $LEDGER)"
    fi
    ;;
  last)
    [ $# -eq 2 ] || { echo "usage: ledger.sh last <phase>" >&2; exit 2; }
    if [ -f "$LEDGER" ] || [ -f "$MAIN_LEDGER" ]; then
      # `|| true`: no match is a normal answer, not a failure — and pipefail
      # would otherwise turn an empty grep into a silent non-zero exit.
      line="$(ledger_view | grep -F " | $2 | " | tail -n 1 || true)"
      [ -n "$line" ] && echo "$line" || echo "(no $2 events yet)"
    else
      echo "(no ledger at $LEDGER)"
    fi
    ;;
  where)
    echo "appends to: $LEDGER"
    echo "read view:  $([ "$LEDGER" != "$MAIN_LEDGER" ] && echo "$MAIN_LEDGER + lane '$SMITHY_LANE'" || echo "$MAIN_LEDGER")"
    ;;
  *)
    echo "usage: ledger.sh append|tail|last|where" >&2; exit 2 ;;
esac
