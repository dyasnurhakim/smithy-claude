#!/usr/bin/env bash
# worktree.sh — isolated git worktrees for smithy's parallel task execution.
#
#   worktree.sh create <job> <task> [base-ref]
#       New worktree + branch smithy/<job>/<task> from base-ref (default HEAD),
#       at ../.smithy-wt-<repo>/<job>-<task>. Drops a .smithy-worktree marker
#       (that marker is what authorizes auto-removal). Prints the path.
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
set -euo pipefail

MAIN_ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
REPO_NAME="$(basename "$MAIN_ROOT")"
WT_BASE="$(dirname "$MAIN_ROOT")/.smithy-wt-$REPO_NAME"
MARKER=".smithy-worktree"

case "${1:-}" in
  create)
    [ $# -ge 3 ] || { echo "usage: worktree.sh create <job> <task> [base-ref]" >&2; exit 2; }
    job="$2"; task="$3"; base="${4:-HEAD}"
    path="$WT_BASE/$job-$task"
    branch="smithy/$job/$task"
    [ -e "$path" ] && { echo "worktree.sh: $path already exists" >&2; exit 1; }
    mkdir -p "$WT_BASE"
    git -C "$MAIN_ROOT" worktree add -b "$branch" "$path" "$base" >&2
    printf 'smithy-worktree job=%s task=%s created=%s\n' "$job" "$task" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$path/$MARKER"
    echo "$path"
    ;;
  integrate)
    [ $# -ge 2 ] || { echo "usage: worktree.sh integrate <job> [base-ref]" >&2; exit 2; }
    job="$2"; base="${3:-HEAD}"
    path="$WT_BASE/$job-integration"
    branch="smithy/$job/integration"
    [ -e "$path" ] && { echo "worktree.sh: $path already exists" >&2; exit 1; }
    mkdir -p "$WT_BASE"
    git -C "$MAIN_ROOT" worktree add -b "$branch" "$path" "$base" >&2
    printf 'smithy-worktree job=%s task=integration created=%s\n' "$job" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$path/$MARKER"
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
    rm -f "$path/$MARKER"   # the marker itself is untracked; drop it pre-removal
    if ! git -C "$MAIN_ROOT" worktree remove "$path" 2>/dev/null; then
      if [ "$force" = "--force" ]; then
        # authorized only AFTER a successful absorb — everything of value is merged
        git -C "$MAIN_ROOT" worktree remove --force "$path"
      else
        printf 'smithy-worktree (marker restored after failed remove)\n' > "$path/$MARKER"
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
