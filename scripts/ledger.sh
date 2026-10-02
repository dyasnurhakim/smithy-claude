#!/usr/bin/env bash
# ledger.sh — the ONE script that writes and reads the smithy ledger (the
# project's event log: one line per event).
#
# Usage:
#   ledger.sh append <phase> <job> <unit> <status> <artifact-path>
#   ledger.sh tail [n]          last n lines (default 20; lane + project events, merged)
#   ledger.sh last <phase>      newest line for one phase (merged view)
#   ledger.sh where             which file gets appended, which files are read
#
# Line format (fields split by " | ", one line per event):
#   2026-07-06T10:22Z | forge | user-auth | task-2 | DONE | jobs/user-auth/reports/task-2-impl.md
set -euo pipefail

# paths.sh finds the file: one ledger per PROJECT, tied to the MAIN worktree.
# (Finding it with --show-toplevel used to split the ledger in a parallel forge
# batch — each linked worktree wrote its own.)
#
# With a LANE active:
#
#   append ──▶ lanes/<name>/ledger.md     (parallel work never mixes lines)
#   read   ◀── ledger.md + lane ledger, merged in timestamp order
#
# A controller that resumes inside a lane (for example after compaction) must
# see the whole history, not only its lane's part. `lane.sh merge` later moves
# the lane's lines into the project ledger for good.
# shellcheck source=./paths.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/paths.sh"
LEDGER="$SMITHY_STATE_DIR/ledger.md"
MAIN_LEDGER="$SMITHY_MEM/ledger.md"

# The read view: project events + lane events, in timestamp order. It equals
# the file lane.sh merge will write later, so a resume decision made inside a
# lane matches the one made after the lane lands.
# Only cat files that exist: this script runs under `set -e -o pipefail`, where
# a `cat` of a ledger that does not exist yet would stop the whole call.
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
      # `|| true`: no match is a normal answer, not a failure. Without it,
      # pipefail would turn an empty grep into a quiet non-zero exit.
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
