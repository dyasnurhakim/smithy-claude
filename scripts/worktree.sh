#!/usr/bin/env bash
# worktree.sh — separate git worktrees (extra checkouts of the same repo) so
# smithy can run tasks in parallel without touching each other's files.
#
#   task branches ──absorb──▶ integration branch ──(verify)──land──▶ working branch
#   smithy/<job>/<task>        smithy/<job>/integration               (main worktree)
#
#   worktree.sh create <job> <task> [base-ref]
#       New worktree + branch smithy/<job>/<task> from base-ref (default HEAD),
#       at ../.smithy-wt-<repo>/<job>-<task>. Writes a .smithy-worktree marker
#       (only a worktree with this marker may be removed by a script). Prints
#       the path. ALSO opens a state lane named <job>-<task> and writes a
#       .smithy-lane marker, so smithy scripts run inside the worktree write
#       their ledger and STATE.md to that lane, not to the shared project files.
#       Separate code without separate state only moves the clash elsewhere.
#   worktree.sh integrate <job> [base-ref]
#       Create the INTEGRATION worktree + branch smithy/<job>/integration.
#       Parallel task branches are absorbed here first and checked; only then
#       are they landed on the working branch.
#   worktree.sh absorb <job> <task>
#       Merge branch smithy/<job>/<task> (--no-ff) into the integration
#       worktree if it exists, else into the MAIN worktree's current branch.
#       On a conflict: abort the merge, exit 1. A conflict means the tasks in
#       the parallel batch touched the same code — escalate to the user.
#   worktree.sh land <job>
#       From the MAIN worktree: merge smithy/<job>/integration into the
#       current (working) branch, once the integration checks passed.
#   worktree.sh remove <path> [--force]
#       Remove a worktree smithy made (the marker is required — user worktrees
#       are refused) and delete its branch with -d. -d fails if the branch is
#       not merged: absorb it first or escalate. Never -D.
#   worktree.sh clean <job>
#       Remove ALL marked worktrees of a job (cleanup after a batch).
#   worktree.sh list
#
# This script does NOT merge lanes. A checkout can be thrown away; a lane's
# ledger events cannot. And the right action differs: landed work ->
# `lane.sh merge`, rolled-back work -> `lane.sh abandon`. So remove/clean only
# report unmerged lanes and leave the choice to the controller.
set -euo pipefail

MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
REPO_NAME="$(basename "$MAIN_ROOT")"
WT_BASE="$(dirname "$MAIN_ROOT")/.smithy-wt-$REPO_NAME"
MARKER=".smithy-worktree"
LANE_MARKER=".smithy-lane"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The marker files are scratch for one checkout and must never reach a commit.
# Without this, an agent's `git add -A` puts them in its task branch, and
# `absorb` then merges them onto the working branch. info/exclude lives in the
# git COMMON dir: shared by every worktree, never committed, and not the
# user's .gitignore. That is the right scope — these files should be untracked
# everywhere in the repo, always.
ensure_markers_excluded() {
  local common exclude pat
  common="$(git -C "$MAIN_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  exclude="$common/info/exclude"
  mkdir -p "$common/info" 2>/dev/null || return 0
  for pat in "$MARKER" "$LANE_MARKER"; do
    grep -qxF "$pat" "$exclude" 2>/dev/null || printf '%s\n' "$pat" >> "$exclude" 2>/dev/null || true
  done
}

# Every worktree gets its own STATE LANE as well as its own checkout. Separate
# code without separate state just moves the clash from the files to the
# ledger. Best effort: if the project's memory folder is not set up yet, the
# worktree still works — it just shares the project state as before.
start_lane() { # start_lane <lane-name> <worktree-path> <job>
  local lane="$1" path="$2" job="$3"
  if ! bash "$SCRIPT_DIR/lane.sh" start "$lane" --worktree "$path" --job "$job" >/dev/null 2>&1; then
    echo "worktree.sh: could not open state lane '$lane' — this worktree will share the project ledger (run scripts/lane.sh status to see why)" >&2
    return 0
  fi
  echo "worktree.sh: state lane '$lane' opened (merge it with: scripts/lane.sh merge $lane)" >&2
}

case "${1:-}" in
  create)
    [ $# -ge 3 ] || { echo "usage: worktree.sh create <job> <task> [base-ref]" >&2; exit 2; }
    job="$2"; task="$3"; base="${4:-HEAD}"
    path="$WT_BASE/$job-$task"
    branch="smithy/$job/$task"
    [ -e "$path" ] && { echo "worktree.sh: $path already exists" >&2; exit 1; }
    mkdir -p "$WT_BASE"
    ensure_markers_excluded
    git -C "$MAIN_ROOT" worktree add -b "$branch" "$path" "$base" >&2
    printf 'smithy-worktree job=%s task=%s created=%s\n' "$job" "$task" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$path/$MARKER"
    start_lane "$job-$task" "$path" "$job"
    echo "$path"
    ;;
  integrate)
    [ $# -ge 2 ] || { echo "usage: worktree.sh integrate <job> [base-ref]" >&2; exit 2; }
    job="$2"; base="${3:-HEAD}"
    path="$WT_BASE/$job-integration"
    branch="smithy/$job/integration"
    [ -e "$path" ] && { echo "worktree.sh: $path already exists" >&2; exit 1; }
    mkdir -p "$WT_BASE"
    ensure_markers_excluded
    git -C "$MAIN_ROOT" worktree add -b "$branch" "$path" "$base" >&2
    printf 'smithy-worktree job=%s task=integration created=%s\n' "$job" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$path/$MARKER"
    start_lane "$job-integration" "$path" "$job"
    echo "$path"
    ;;
  absorb)
    [ $# -eq 3 ] || { echo "usage: worktree.sh absorb <job> <task>" >&2; exit 2; }
    job="$2"; task="$3"
    branch="smithy/$job/$task"
    git -C "$MAIN_ROOT" rev-parse --verify -q "$branch" >/dev/null || { echo "worktree.sh: branch $branch not found" >&2; exit 1; }
    # Merge into the integration worktree if it exists, else the main worktree.
    target="$MAIN_ROOT"; target_name="working branch"
    if [ -d "$WT_BASE/$job-integration" ]; then
      target="$WT_BASE/$job-integration"; target_name="integration branch"
    fi
    if ! git -C "$target" merge --no-ff -m "merge: $branch (smithy parallel task)" "$branch"; then
      git -C "$target" merge --abort || true
      echo "worktree.sh: MERGE CONFLICT absorbing $branch into the $target_name — tasks in the batch touched the same code. Merge aborted; escalate to the user." >&2
      exit 1
    fi
    echo "absorbed $branch into $target_name"
    ;;
  land)
    [ $# -eq 2 ] || { echo "usage: worktree.sh land <job>" >&2; exit 2; }
    branch="smithy/$2/integration"
    git -C "$MAIN_ROOT" rev-parse --verify -q "$branch" >/dev/null || { echo "worktree.sh: no integration branch $branch" >&2; exit 1; }
    if ! git -C "$MAIN_ROOT" merge --no-ff -m "merge: $branch (smithy integrated batch)" "$branch"; then
      git -C "$MAIN_ROOT" merge --abort || true
      echo "worktree.sh: MERGE CONFLICT landing $branch — the working branch moved during the batch. Merge aborted; escalate to the user." >&2
      exit 1
    fi
    echo "landed $branch onto the working branch"
    ;;
  remove)
    [ $# -ge 2 ] || { echo "usage: worktree.sh remove <path> [--force]" >&2; exit 2; }
    path="$2"; force="${3:-}"
    [ -d "$path" ] || { echo "worktree.sh: no such worktree dir: $path" >&2; exit 1; }
    if [ ! -f "$path/$MARKER" ]; then
      echo "worktree.sh: REFUSING to remove $path — no smithy marker. This looks like a user-created worktree: ASK the user whether to remove it or leave it." >&2
      exit 1
    fi
    branch="$(git -C "$path" branch --show-current 2>/dev/null || true)"
    lane="$(head -n 1 "$path/$LANE_MARKER" 2>/dev/null || true)"
    rm -f "$path/$MARKER" "$path/$LANE_MARKER"   # untracked markers; delete them before the remove
    if ! git -C "$MAIN_ROOT" worktree remove "$path" 2>/dev/null; then
      if [ "$force" = "--force" ]; then
        # Allowed only AFTER a successful absorb: everything of value is merged.
        git -C "$MAIN_ROOT" worktree remove --force "$path"
      else
        printf 'smithy-worktree (marker restored after failed remove)\n' > "$path/$MARKER"
        [ -n "$lane" ] && printf '%s\n' "$lane" > "$path/$LANE_MARKER"
        echo "worktree.sh: $path has uncommitted/untracked files:" >&2
        git -C "$path" status --short >&2
        echo "worktree.sh: if the branch was absorbed and these files can be thrown away, run again with --force; otherwise escalate." >&2
        exit 1
      fi
    fi
    if [ -n "$branch" ]; then
      git -C "$MAIN_ROOT" branch -d "$branch" 2>&1 | sed 's/^/worktree.sh: /' >&2 || \
        echo "worktree.sh: branch $branch not fully merged — left in place (absorb it or escalate)" >&2
    fi
    echo "removed $path"
    # The checkout can be thrown away; the lane's EVENTS cannot. Removing a
    # worktree must never quietly lose them. Merging is a choice (a rolled-back
    # batch needs `lane.sh abandon` instead), so we only report.
    if [ -n "$lane" ] && [ -d "$(bash "$SCRIPT_DIR/paths.sh" mem)/lanes/$lane" ]; then
      echo "worktree.sh: state lane '$lane' is still unmerged — run 'scripts/lane.sh merge $lane' (or 'abandon' it if the work was discarded)" >&2
    fi
    ;;
  clean)
    [ $# -eq 2 ] || { echo "usage: worktree.sh clean <job>" >&2; exit 2; }
    job="$2"; removed=0
    for path in "$WT_BASE/$job-"*; do
      [ -d "$path" ] || continue
      [ -f "$path/$MARKER" ] || { echo "worktree.sh: skipping unmarked $path (ask the user)" >&2; continue; }
      "$0" remove "$path" --force && removed=$((removed+1))
    done
    rmdir "$WT_BASE" 2>/dev/null || true
    echo "cleaned $removed worktree(s) for job '$job'"
    ;;
  list)
    git -C "$MAIN_ROOT" worktree list
    ;;
  *)
    echo "usage: worktree.sh create|integrate|absorb|land|remove|clean|list" >&2; exit 2 ;;
esac
