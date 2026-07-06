#!/usr/bin/env bash
# ledger.sh — single writer/reader for the smithy per-project event ledger.
#
# Usage:
#   ledger.sh append <phase> <job> <unit> <status> <artifact-path>
#   ledger.sh tail [n]          (default 20)
#   ledger.sh last <phase>      (most recent line for a phase)
#
# Line format (pipe-delimited, one line per event):
#   2026-07-06T10:22Z | forge | user-auth | task-2 | DONE | jobs/user-auth/reports/task-2-impl.md
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LEDGER="$PROJECT_ROOT/docs/smithy/ledger.md"
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
    [ -f "$LEDGER" ] && tail -n "$n" "$LEDGER" || echo "(no ledger at $LEDGER)"
    ;;
  last)
    [ $# -eq 2 ] || { echo "usage: ledger.sh last <phase>" >&2; exit 2; }
    [ -f "$LEDGER" ] && grep -F " | $2 | " "$LEDGER" | tail -n 1 || echo "(no ledger at $LEDGER)"
    ;;
  *)
    echo "usage: ledger.sh append|tail|last" >&2; exit 2 ;;
esac
