#!/usr/bin/env bash
# review-package.sh — build the one file a reviewer reads.
#
#   review-package.sh record-base
#       Save the current HEAD as the JOB's base (the "- Base sha:" line in
#       STATE.md). Run it ONCE, when a job starts — never per task, or the
#       final review would only see the last task.
#
#   review-package.sh build [--base <ref>] <brief> <out> [report] [target] [path...]
#       Write a review package: the brief, the commit list, the changed-file
#       list and the diff from BASE to TARGET.
#         --base <ref>  compare from this ref instead of STATE.md's base.
#                       Must come right after "build" (arguments are by position).
#                       Use it for standalone reviews: it never edits STATE.md,
#                       so another job's base is left alone.
#         report        an implementer report file, OR a reports folder, or ""
#                       for none (use "" when you only want to give a target).
#         target        HEAD (default), a branch such as smithy/<job>/<task>,
#                       or WORKTREE to include uncommitted AND untracked files.
#         path...       only show the diff for these paths (the file list
#                       still shows everything).
#
#   BASE ──────────── commits ──────────── TARGET
#    │                                       │
#    └──── one diff: everything the job did ─┘   (never HEAD~1: that drops
#                                                 all but the last commit)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"
git rev-parse --show-toplevel >/dev/null 2>&1 || { echo "review-package.sh: not a git repo" >&2; exit 1; }
# Diffs come from THIS worktree (a parallel task branch may be checked out in
# a linked one). STATE.md is the CURRENT state folder's: a lane's own when a
# lane is active (so two jobs never overwrite each other's base), else the
# project's. A lane with no base yet falls back to the project's STATE.md.
PROJECT_ROOT="$SMITHY_ROOT"
STATE="$SMITHY_STATE_DIR/STATE.md"
PROJECT_STATE="$SMITHY_MEM/STATE.md"
read_base() { grep -m1 '^- Base sha:' "$1" 2>/dev/null | awk '{print $4}'; }
USAGE="usage: review-package.sh record-base | build [--base <ref>] <brief> <out> [impl-report] [target] [path...]"

case "${1:-}" in
  record-base)
    sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
    mkdir -p "$(dirname "$STATE")"
    touch "$STATE"
    if grep -q '^- Base sha:' "$STATE"; then
      # Write a temp file and move it: works the same on GNU and BSD/macOS sed.
      sed "s|^- Base sha:.*|- Base sha: $sha|" "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    else
      printf -- '- Base sha: %s\n' "$sha" >> "$STATE"
    fi
    echo "base=$sha"
    ;;
  build)
    shift
    base=""
    if [ "${1:-}" = "--base" ]; then
      [ -n "${2:-}" ] || { echo "review-package.sh: --base needs a ref" >&2; exit 2; }
      base="$2"; shift 2
    fi
    [ $# -ge 2 ] || { echo "$USAGE" >&2; exit 2; }
    for a in "$@"; do
      case "$a" in --*) echo "review-package.sh: '$a' is in the wrong place — options go right after 'build'" >&2; exit 2 ;; esac
    done
    brief="$1"; out="$2"; report="${3:-}"; target="${4:-HEAD}"
    shift 2; [ $# -gt 0 ] && shift; [ $# -gt 0 ] && shift
    PATHSPEC=("$@")
    # How many context lines around each change (config key review_diff_context, default 5).
    U="$(bash "$SCRIPT_DIR/config.sh" get review_diff_context 2>/dev/null)" || U=""
    case "$U" in ''|*[!0-9]*) U=5 ;; esac
    [ -f "$brief" ] || { echo "review-package.sh: brief not found: $brief" >&2; exit 1; }
    if [ -z "$base" ]; then
      base="$(read_base "$STATE")" || true
      if { [ -z "${base:-}" ] || [ "$base" = "none" ]; } && [ "$STATE" != "$PROJECT_STATE" ]; then
        base="$(read_base "$PROJECT_STATE")" || true
      fi
      [ -n "${base:-}" ] && [ "$base" != "none" ] || {
        echo "review-package.sh: no base in $STATE — pass --base <ref>, or run record-base when the job starts" >&2; exit 1; }
    fi
    git -C "$PROJECT_ROOT" rev-parse --verify -q "$base^{commit}" >/dev/null || { echo "review-package.sh: base '$base' is not a commit in this repo" >&2; exit 1; }
    if [ "$target" = "WORKTREE" ]; then
      head_label="working tree (uncommitted and untracked files included)"
      log_range="$base..HEAD"
      diff_args=("$base")
      # Plain `git diff <base>` skips files git does not track yet. Mark them
      # "intent to add" in a throw-away COPY of the index, so the real index
      # and your files are never touched.
      tmp_index="$(mktemp)"
      real_index="$(git -C "$PROJECT_ROOT" rev-parse --git-path index)"
      case "$real_index" in /*) ;; *) real_index="$PROJECT_ROOT/$real_index" ;; esac
      if [ -f "$real_index" ]; then cp "$real_index" "$tmp_index"; else rm -f "$tmp_index"; fi
      GIT_INDEX_FILE="$tmp_index" git -C "$PROJECT_ROOT" add -N -A -- . >/dev/null 2>&1 || true
      export GIT_INDEX_FILE="$tmp_index"
      trap 'rm -f "$tmp_index"' EXIT
    else
      git -C "$PROJECT_ROOT" rev-parse --verify -q "$target^{commit}" >/dev/null || { echo "review-package.sh: target '$target' is not a commit" >&2; exit 1; }
      head_label="$(git -C "$PROJECT_ROOT" rev-parse "$target") ($target)"
      log_range="$base..$target"
      diff_args=("$base..$target")
    fi
    mkdir -p "$(dirname "$out")"
    {
      echo "# Review Package"
      echo
      echo "Base: $base"
      echo "Head: $head_label"
      echo
      echo "## Task Brief"
      echo
      cat "$brief"
      echo
      echo "## Commits ($log_range)"
      echo
      git -C "$PROJECT_ROOT" log --oneline "$log_range"
      echo
      echo "## Changed files (all of them, before any path filter)"
      echo
      git -C "$PROJECT_ROOT" diff --stat "${diff_args[@]}"
      echo
      if [ ${#PATHSPEC[@]} -gt 0 ]; then
        echo "## Diff (-U$U) — ONLY for: ${PATHSPEC[*]} (full file list above)"
        echo
        git -C "$PROJECT_ROOT" diff -U"$U" "${diff_args[@]}" -- "${PATHSPEC[@]}"
      else
        echo "## Full Diff (-U$U)"
        echo
        git -C "$PROJECT_ROOT" diff -U"$U" "${diff_args[@]}"
      fi
      if [ -n "$report" ] && [ -e "$report" ]; then
        echo
        echo "## Implementer reports (NOT checked — verify every claim yourself)"
        if [ -d "$report" ]; then
          echo "Read the reports in: $report"
          find "$report" -maxdepth 1 -type f -name '*.md' | sort | sed 's/^/- /'
        else
          echo "Read it at: $report"
        fi
      fi
    } > "$out"
    echo "package=$out lines=$(wc -l < "$out")"
    ;;
  *)
    echo "$USAGE" >&2; exit 2 ;;
esac
