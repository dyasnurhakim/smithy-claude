#!/usr/bin/env bash
# worktree.sh — isolated git worktrees for smithy's parallel task execution.
#
#   worktree.sh create <job> <task> [base-ref]
#       New worktree + branch smithy/<job>/<task> from base-ref (default HEAD),
#       at ../.smithy-wt-<repo>/<job>-<task>. Drops a .smithy-worktree marker
#       (that marker is what authorizes auto-removal). Prints the path.
#       ALSO opens a state lane named <job>-<task> and drops a .smithy-lane
#       marker, so smithy scripts run inside the worktree write their ledger
#       and STATE.md into that lane instead of the shared project ones. Code
#       isolation without state isolation only relocates the collision.
#   worktree.sh integrate <job> [base-ref]
#       Create the INTEGRATION worktree + branch smithy/<job>/integration.
#       Parallel task branches are absorbed here first, verified, and only
#       then landed onto the working branch.
#   worktree.sh absorb <job> <task>
#       Merge branch smithy/<job>/<task> (--no-ff) into the integration
#       worktree when one exists, else into the MAIN worktree's current
#       branch. Conflict -> aborts the merge, exit 1 (a conflict means the
#       parallel batch was NOT disjoint — escalate).
#   worktree.sh land <job>
#       From the MAIN worktree: merge smithy/<job>/integration into the
#       current (working) branch after integration verification passed.
#   worktree.sh remove <path>
#       Remove a worktree smithy created (marker required — refuses user
#       worktrees) and delete its branch with -d (fails if unmerged: absorb
#       first or escalate; never -D).
#   worktree.sh clean <job>
#       Remove ALL marked worktrees of a job (post-batch cleanup).
#   worktree.sh list
#
# Lanes are NOT merged by this script. Removing a checkout is disposable;
# discarding a lane's ledger events is not, and the right call differs (landed
# work -> `lane.sh merge`, rolled-back work -> `lane.sh abandon`). remove/clean
# report unmerged lanes and leave the decision to the controller.
set -euo pipefail

MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
REPO_NAME="$(basename "$MAIN_ROOT")"
WT_BASE="$(dirname "$MAIN_ROOT")/.smithy-wt-$REPO_NAME"
MARKER=".smithy-worktree"
LANE_MARKER=".smithy-lane"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Every worktree gets its own STATE LANE as well as its own checkout — code
# isolation without state isolation just moves the collision from the files to
# the ledger. Best-effort: a project whose memory dir is not initialised yet
# still gets a working worktree, it just shares the project state as before.
# The markers are per-checkout scratch and must never reach a commit. Without
# this, an agent's `git add -A` sweeps them into its task branch and `absorb`
# then merges that scratch onto the working branch. info/exclude lives in the
# git COMMON dir (shared by every worktree, never committed, not the user's
# .gitignore) — which is exactly the right scope: these files should be
# untracked everywhere in the repo, always.
ensure_markers_excluded() {
  local common exclude pat
  common="$(git -C "$MAIN_ROOT" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 0
  exclude="$common/info/exclude"
  mkdir -p "$common/info" 2>/dev/null || return 0
  for pat in "$MARKER" "$LANE_MARKER"; do
    grep -qxF "$pat" "$exclude" 2>/dev/null || printf '%s\n' "$pat" >> "$exclude" 2>/dev/null || true
  done
}

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
    # target: integration worktree when present, else the main worktree
    target="$MAIN_ROOT"; target_name="working branch"
    if [ -d "$WT_BASE/$job-integration" ]; then
      target="$WT_BASE/$job-integration"; target_name="integration branch"
    fi
    if ! git -C "$target" merge --no-ff -m "merge: $branch (smithy parallel task)" "$branch"; then
      git -C "$target" merge --abort || true
      echo "worktree.sh: MERGE CONFLICT absorbing $branch into the $target_name — the batch was not disjoint. Merge aborted; escalate to the user." >&2
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
    rm -f "$path/$MARKER" "$path/$LANE_MARKER"   # untracked markers; drop pre-removal
    if ! git -C "$MAIN_ROOT" worktree remove "$path" 2>/dev/null; then
      if [ "$force" = "--force" ]; then
        # authorized only AFTER a successful absorb — everything of value is merged
        git -C "$MAIN_ROOT" worktree remove --force "$path"
      else
        printf 'smithy-worktree (marker restored after failed remove)\n' > "$path/$MARKER"
        [ -n "$lane" ] && printf '%s\n' "$lane" > "$path/$LANE_MARKER"
        echo "worktree.sh: $path has uncommitted/untracked files:" >&2
        git -C "$path" status --short >&2
        echo "worktree.sh: if the branch was absorbed and these are disposable, re-run with --force; otherwise escalate." >&2
        exit 1
      fi
    fi
    if [ -n "$branch" ]; then
      git -C "$MAIN_ROOT" branch -d "$branch" 2>&1 | sed 's/^/worktree.sh: /' >&2 || \
        echo "worktree.sh: branch $branch not fully merged — left in place (absorb it or escalate)" >&2
    fi
    echo "removed $path"
    # The checkout is disposable; the lane's EVENTS are not. Removing a
    # worktree must never silently discard them, and merging is a decision
    # (a rolled-back batch wants `lane.sh abandon` instead) — so: report only.
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
    echo "usage: worktree.sh create|absorb|remove|clean|list" >&2; exit 2 ;;
esac
