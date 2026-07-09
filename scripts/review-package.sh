#!/usr/bin/env bash
# review-package.sh — build the file a code-reviewer agent reads.
#
# Usage:
#   review-package.sh record-base
#       Record current HEAD as the review base: updates the "- Base sha:" line
#       in docs/smithy/STATE.md. Run BEFORE dispatching an implementor.
#   review-package.sh build <brief-file> <out-file> [implementor-report-file] [ref]
#       Build a review package from BASE..<ref> (default ref: HEAD; pass a
#       branch like smithy/<job>/<task> to review a parallel task's branch
#       before absorbing it). BASE is read from STATE.md — never HEAD~1,
#       which silently drops all but the last commit.
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "review-package.sh: not a git repo" >&2; exit 1; }
STATE="$PROJECT_ROOT/docs/smithy/STATE.md"

case "${1:-}" in
  record-base)
    sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD)"
    mkdir -p "$(dirname "$STATE")"
    touch "$STATE"
    if grep -q '^- Base sha:' "$STATE"; then
      # portable in-place edit (BSD/macOS sed -i needs a suffix arg; avoid entirely)
      sed "s|^- Base sha:.*|- Base sha: $sha|" "$STATE" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"
    else
      printf -- '- Base sha: %s\n' "$sha" >> "$STATE"
    fi
    echo "base=$sha"
    ;;
  build)
    [ $# -ge 3 ] || { echo "usage: review-package.sh build <brief> <out> [impl-report] [ref] [pathspec...]" >&2; exit 2; }
    brief="$2"; out="$3"; report="${4:-}"; ref="${5:-HEAD}"
    shift; shift; shift; [ $# -gt 0 ] && shift; [ $# -gt 0 ] && shift
    # remaining args = optional pathspecs to scope the diff (persona slices)
    PATHSPEC=("$@")
    # diff context lines: docs/smithy/config.json review_diff_context, default 5
    U="$(python3 -c "
import json,sys
try: print(int(json.load(open('$PROJECT_ROOT/docs/smithy/config.json')).get('review_diff_context',5)))
except Exception: print(5)" 2>/dev/null || echo 5)"
    [ -f "$brief" ] || { echo "review-package.sh: brief not found: $brief" >&2; exit 1; }
    base="$(grep -m1 '^- Base sha:' "$STATE" 2>/dev/null | awk '{print $4}')" || true
    [ -n "${base:-}" ] && [ "$base" != "none" ] || { echo "review-package.sh: no base sha in $STATE — run record-base first" >&2; exit 1; }
    git -C "$PROJECT_ROOT" cat-file -e "$base" 2>/dev/null || { echo "review-package.sh: base sha $base not found in repo" >&2; exit 1; }
    mkdir -p "$(dirname "$out")"
    {
      echo "# Review Package"
      echo
      echo "Base: $base"
      echo "Head: $(git -C "$PROJECT_ROOT" rev-parse "$ref") ($ref)"
      echo
      echo "## Task Brief"
      echo
      cat "$brief"
      echo
      echo "## Commits ($base..$ref)"
      echo
      git -C "$PROJECT_ROOT" log --oneline "$base..$ref"
      echo
      echo "## Changed files (full list, before any path scoping)"
      echo
      git -C "$PROJECT_ROOT" diff --stat "$base..$ref"
      echo
      if [ ${#PATHSPEC[@]} -gt 0 ]; then
        echo "## Diff (-U$U) — SCOPED to: ${PATHSPEC[*]} (full file list above)"
        echo
        git -C "$PROJECT_ROOT" diff -U"$U" "$base..$ref" -- "${PATHSPEC[@]}"
      else
        echo "## Full Diff (-U$U)"
        echo
        git -C "$PROJECT_ROOT" diff -U"$U" "$base..$ref"
      fi
      if [ -n "$report" ] && [ -f "$report" ]; then
        echo
        echo "## Implementor Report (UNVERIFIED — do not trust; verify every claim)"
        echo "Read it at: $report"
      fi
    } > "$out"
    echo "package=$out lines=$(wc -l < "$out")"
    ;;
  *)
    echo "usage: review-package.sh record-base | build <brief> <out> [impl-report]" >&2; exit 2 ;;
esac
