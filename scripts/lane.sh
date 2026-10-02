#!/usr/bin/env bash
# lane.sh — state lanes, so parallel work does not clash over shared state.
#
# $SMITHY_MEM is ONE folder per project, tied to the main worktree. That is on
# purpose (one shared ledger beats a split one). But two pieces of work running
# at once — the tasks of a parallel forge batch, or two whole pipelines — would
# then append to the same ledger.md and overwrite the same STATE.md. A lane
# gives each piece of work its own copy of the CHANGING state, and merges it
# back when the work lands:
#
#   start ──▶ lanes/<name>/{STATE,ledger,decisions}.md ──▶ merge ──▶ project files
#                    (work writes here)                     │
#                                                           └──▶ lanes/.merged/<name>-<ts>/
#
#   lane.sh start <name> [--worktree <path>] [--job <slug>]
#       Create $SMITHY_MEM/lanes/<name>/ with a starting STATE.md. With
#       --worktree, also write a .smithy-lane marker in that checkout. Then
#       every smithy script run inside it finds this lane by itself — the
#       agent needs to know nothing. Prints the lane's state folder.
#   lane.sh current
#       The lane found HERE (env > marker > none) and its state folder.
#   lane.sh list
#       Every lane with its event count and last event.
#   lane.sh merge <name>
#       Merge the lane into the project state:
#         - ledger lines from both files are combined, in timestamp order;
#         - the lane's decisions.md is appended to the project's;
#         - the project STATE.md "Last event" line is updated.
#       Then the whole lane folder (its STATE.md too) is archived (kept, not
#       deleted) under lanes/.merged/<name>-<ts>/.
#   lane.sh merge-all
#       Merge every active lane, oldest first. Use it once a parallel batch has
#       fully landed.
#   lane.sh abandon <name>
#       Archive a lane WITHOUT merging (its events never reach the ledger).
#       For a batch that was rolled back. Never deletes anything quietly.
#   lane.sh status
#       current + list + whether a merge is running.
#
# What a lane does NOT get its own copy of: config.json (a lane is a piece of
# work, not a different set of settings), jobs/ (files are only added, and
# their names already carry the job slug), personas/, DESIGN.md, and the guard
# tokens. Permission is per project and per user, never per lane: a lane must
# never be able to give itself a commit grant.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"

LANES_DIR="$SMITHY_MEM/lanes"
ARCHIVE_DIR="$LANES_DIR/.merged"
LOCK="$LANES_DIR/.merge-lock"
STATE_FILES="STATE.md ledger.md decisions.md"

die() { echo "lane.sh: $*" >&2; exit 1; }
ts()  { date -u +%Y-%m-%dT%H:%MZ; }

require_name() { # checked with the same rule paths.sh uses to find a lane
  [ -n "${1:-}" ] || die "lane name required"
  _smithy_lane_ok "$1" || die "invalid lane name '$1' — use [A-Za-z0-9._-], no leading dot, no '..'"
}

lane_dir() { echo "$LANES_DIR/$1"; }

# A merge rewrites the shared ledger, so two controllers merging at once could
# mix their writes. We lock with mkdir: it is atomic (it fully succeeds or
# fully fails) on every POSIX filesystem. A lock file written with > is not.
lock_acquire() {
  mkdir -p "$LANES_DIR"
  if ! mkdir "$LOCK" 2>/dev/null; then
    die "a merge is already running ($LOCK). If no other merge is running, remove that folder and try again."
  fi
  trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
}

seed_state() { # seed_state <lane-dir> <lane-name> <job>
  local dir="$1" name="$2" job="$3"
  if [ -f "$SMITHY_MEM/STATE.md" ]; then
    # Copy the project's base sha and active job into the lane, so the agent
    # working there does not start blind.
    sed "s|^# Smithy State$|# Smithy State (lane: $name)|" "$SMITHY_MEM/STATE.md" > "$dir/STATE.md"
  else
    cat > "$dir/STATE.md" <<EOF
# Smithy State (lane: $name)
- Active job: ${job:-unknown}
- Phase: IDLE
- Base sha: none
- Last event: $(ts) lane $name STARTED
- Blockers: none
- Next step: (set by the skill running in this lane)
EOF
  fi
  : > "$dir/ledger.md"
}

case "${1:-}" in
  start)
    shift
    name="${1:-}"; require_name "$name"; shift || true
    worktree=""; job=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --worktree) worktree="${2:-}"; shift 2 || die "--worktree needs a path" ;;
        --job)      job="${2:-}";      shift 2 || die "--job needs a slug" ;;
        *) die "unknown flag '$1'" ;;
      esac
    done
    [ -d "$SMITHY_MEM" ] || die "no project memory at $SMITHY_MEM ($SMITHY_MEM_SOURCE) — run init-memory.sh first"
    dir="$(lane_dir "$name")"
    [ -d "$dir" ] && die "lane '$name' already exists at $dir (merge or abandon it first)"
    mkdir -p "$dir" || die "cannot create $dir"
    seed_state "$dir" "$name" "$job"
    if [ -n "$worktree" ]; then
      [ -d "$worktree" ] || die "--worktree path does not exist: $worktree"
      printf '%s\n' "$name" > "$worktree/.smithy-lane" || die "cannot write the lane marker in $worktree"
      echo "lane.sh: marker written — everything run inside $worktree now uses lane '$name'" >&2
    fi
    echo "$dir"
    ;;

  current)
    if [ -n "${SMITHY_LANE:-}" ]; then
      echo "lane:      $SMITHY_LANE ($SMITHY_LANE_SOURCE)"
    else
      echo "lane:      (none) — state goes to the shared project folder"
    fi
    echo "state dir: $SMITHY_STATE_DIR"
    [ -n "${SMITHY_LANE_WARN:-}" ] && echo "WARNING:   $SMITHY_LANE_WARN" >&2
    true
    ;;

  list)
    [ -d "$LANES_DIR" ] || { echo "(no lanes at $LANES_DIR)"; exit 0; }
    found=0
    printf "%-24s %-7s %s\n" "LANE" "EVENTS" "LAST EVENT"
    for dir in "$LANES_DIR"/*; do
      [ -d "$dir" ] || continue
      base="$(basename "$dir")"
      [ "$base" = ".merged" ] && continue
      found=1
      n=0; last="(none)"
      if [ -f "$dir/ledger.md" ]; then
        n="$(wc -l < "$dir/ledger.md" | tr -d ' ')"
        [ "$n" -gt 0 ] && last="$(tail -n 1 "$dir/ledger.md")"
      fi
      printf "%-24s %-7s %s\n" "$base" "$n" "$last"
    done
    [ "$found" -eq 0 ] && echo "(no active lanes)"
    true
    ;;

  merge)
    name="${2:-}"; require_name "$name"
    dir="$(lane_dir "$name")"
    [ -d "$dir" ] || die "no such lane: $name (see 'lane.sh list')"
    lock_acquire

    merged=0
    if [ -s "$dir/ledger.md" ]; then
      main="$SMITHY_MEM/ledger.md"
      touch "$main"
      tmp="$main.merge.$$"
      # Sort by the ISO timestamp at the start of each line. Timestamps only
      # go down to the minute, so ties are common. -s (stable sort) keeps each
      # file's own order, and puts the project's events before the lane's
      # when they share a minute.
      cat "$main" "$dir/ledger.md" | sort -s -k1,1 > "$tmp" || { rm -f "$tmp"; die "ledger merge failed"; }
      mv "$tmp" "$main" || die "could not replace $main"
      merged="$(wc -l < "$dir/ledger.md" | tr -d ' ')"
    fi

    if [ -s "$dir/decisions.md" ]; then
      { printf '\n<!-- merged from lane %s at %s -->\n' "$name" "$(ts)"; cat "$dir/decisions.md"; } \
        >> "$SMITHY_MEM/decisions.md" || die "could not append decisions.md"
    fi

    # Update only the STATE.md line a script can work out ("Last event").
    # Phase and Next step need judgment, so the controller rewrites them.
    # A guess here would show the next session a wrong "next step".
    if [ -f "$SMITHY_MEM/STATE.md" ] && [ -s "$SMITHY_MEM/ledger.md" ]; then
      last_line="$(tail -n 1 "$SMITHY_MEM/ledger.md")"
      lts="$(echo "$last_line"  | awk -F' \\| ' '{print $1}')"
      lph="$(echo "$last_line"  | awk -F' \\| ' '{print $2}')"
      lun="$(echo "$last_line"  | awk -F' \\| ' '{print $4}')"
      lst="$(echo "$last_line"  | awk -F' \\| ' '{print $5}')"
      tmp="$SMITHY_MEM/STATE.md.merge.$$"
      sed "s|^- Last event:.*$|- Last event: $lts $lph $lun $lst|" "$SMITHY_MEM/STATE.md" > "$tmp" \
        && mv "$tmp" "$SMITHY_MEM/STATE.md" || rm -f "$tmp"
    fi

    mkdir -p "$ARCHIVE_DIR"
    dest="$ARCHIVE_DIR/$name-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$dir" "$dest" || die "merged, but could not archive the lane folder $dir"

    echo "merged lane '$name': $merged ledger event(s) added to $SMITHY_MEM/ledger.md"
    echo "archived: $dest"
    echo "NOTE: STATE.md 'Last event' was updated. You must rewrite Phase and Next step yourself."
    ;;

  merge-all)
    [ -d "$LANES_DIR" ] || { echo "(no lanes to merge)"; exit 0; }
    any=0
    for dir in "$LANES_DIR"/*; do
      [ -d "$dir" ] || continue
      base="$(basename "$dir")"
      [ "$base" = ".merged" ] && continue
      any=1
      bash "$0" merge "$base" || die "merge-all stopped at lane '$base' — fix it, then run again"
    done
    [ "$any" -eq 0 ] && echo "(no active lanes to merge)"
    true
    ;;

  abandon)
    name="${2:-}"; require_name "$name"
    dir="$(lane_dir "$name")"
    [ -d "$dir" ] || die "no such lane: $name"
    mkdir -p "$ARCHIVE_DIR"
    dest="$ARCHIVE_DIR/$name-abandoned-$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$dir" "$dest" || die "could not archive $dir"
    echo "abandoned lane '$name' — its events did NOT reach the ledger"
    echo "archived: $dest"
    ;;

  status)
    bash "$0" current
    echo
    bash "$0" list
    [ -d "$LOCK" ] && echo && echo "WARNING: a merge lock is held ($LOCK)" >&2
    true
    ;;

  ""|-h|--help)
    awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "${BASH_SOURCE[0]}"
    [ -n "${1:-}" ] || exit 2 ;;
  *)
    die "unknown command '$1' (try --help)" ;;
esac
