#!/usr/bin/env bash
# start.sh — step 1 of every smithy skill, in one call.
#
#   start.sh <skill> [auto|new|<slug>]
#
# It does four things and prints a short summary:
#   1. finds the memory folder (creates it the first time);
#   2. reads STATE.md (active job, phase, base);
#   3. picks the job slug for this run;
#   4. logs "<skill> <slug> - STARTED" in the ledger.
#
# Slug modes:
#   auto    use the active job if one is running, else make a new one (default)
#   new     always make a new one: <skill>-<YYYY-MM-DD>, then -2, -3 ... if taken
#   <slug>  use exactly this (kebab-case: a-z, 0-9 and dashes)
#
# Exit codes:
#   0  ready — read the summary
#   3  nobody has decided WHERE memory lives yet. Ask the user (in repo /
#      outside the repo / a folder they name), run init-memory.sh with the
#      answer, then run start.sh again.
#   4  not inside a git repo — skills that need git must stop and say so
#   2  bad arguments
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

skill="${1:-}"; mode="${2:-auto}"
[ -n "$skill" ] || { echo "usage: start.sh <skill> [auto|new|<slug>]" >&2; exit 2; }
# Names become folder names: kebab-case only, so nothing can escape the memory folder.
is_kebab() { printf '%s' "$1" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; }
is_kebab "$skill" || { echo "start.sh: skill name must be kebab-case (got '$skill')" >&2; exit 2; }
case "$mode" in
  auto|new) ;;
  *) is_kebab "$mode" || { echo "start.sh: slug must be kebab-case (got '$mode')" >&2; exit 2; } ;;
esac

git rev-parse --show-toplevel >/dev/null 2>&1 || {
  echo "smithy start: $skill"
  echo "memory: none — this folder is not a git repo"
  exit 4
}

# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"

# 1. memory folder
if [ ! -f "$SMITHY_MEM/STATE.md" ]; then
  init_out="$(bash "$SCRIPT_DIR/init-memory.sh" 2>&1)"; rc=$?
  if [ "$rc" -eq 3 ]; then
    echo "smithy start: $skill"
    echo "ASK THE USER: where should smithy keep its memory for this project?"
    echo "  in the repo      → bash $SCRIPT_DIR/init-memory.sh --in-repo"
    echo "  outside the repo → bash $SCRIPT_DIR/init-memory.sh --external"
    echo "  a folder I name  → bash $SCRIPT_DIR/init-memory.sh --at <dir>"
    echo "(add --global-default repo|external to stop being asked in new projects)"
    exit 3
  fi
  [ "$rc" -eq 0 ] || { echo "$init_out" >&2; exit "$rc"; }
  # paths may have changed (a new registry entry) — resolve again
  . "$SCRIPT_DIR/paths.sh"
fi

# 2. STATE.md
state_line() { grep -m1 "^- $1:" "$SMITHY_STATE_DIR/STATE.md" 2>/dev/null | sed "s/^- $1: *//"; }
active="$(state_line 'Active job')"; phase="$(state_line 'Phase')"; base="$(state_line 'Base sha')"
active_slug=""
case "$active" in jobs/*) active_slug="${active#jobs/}"; active_slug="${active_slug%/}" ;; esac
case "$phase" in IDLE*|"") active_slug="" ;; esac   # a finished job is not "active"
if [ -n "$active_slug" ] && ! is_kebab "$active_slug"; then
  echo "start.sh: ignoring odd Active job in STATE.md ('$active')" >&2
  active_slug=""
fi

# 3. slug
# Claim a new slug with a plain `mkdir` (no -p): it fails if the folder
# exists, so two runs at the same moment can never get the same slug.
new_slug() {
  local s="$skill-$(date -u +%Y-%m-%d)" n=2
  local try="$s"
  mkdir -p "$SMITHY_MEM/jobs"
  until mkdir "$SMITHY_MEM/jobs/$try" 2>/dev/null; do try="$s-$n"; n=$((n + 1)); done
  echo "$try"
}
case "$mode" in
  auto) if [ -n "$active_slug" ]; then slug="$active_slug"; why="active job"; else slug="$(new_slug)"; why="new"; fi ;;
  new)  slug="$(new_slug)"; why="new" ;;
  *)    slug="$mode"; why="given" ;;
esac
mkdir -p "$SMITHY_MEM/jobs/$slug/reports"

# 4. ledger
bash "$SCRIPT_DIR/ledger.sh" append "$skill" "$slug" - STARTED - >/dev/null

echo "smithy start: $skill"
echo "memory: $SMITHY_MEM"
echo "job: $slug ($why) → $SMITHY_MEM/jobs/$slug/"
echo "state: active=${active_slug:-none} phase=${phase:-none} base=${base:-none}"
# lane.sh list prints a header, then one row per ACTIVE lane, or "(no …)" lines.
lanes="$(bash "$SCRIPT_DIR/lane.sh" list 2>/dev/null | grep -v -e '^(no ' -e '^LANE ' || true)"
[ -z "$lanes" ] || { echo "UNMERGED LANES (a parallel batch did not finish — see memory.md § Lanes):"; echo "$lanes" | sed 's/^/  /'; }
echo "recent events:"
bash "$SCRIPT_DIR/ledger.sh" tail 5 | sed 's/^/  /'
