#!/usr/bin/env bash
# review-package.sh — build the file a code-reviewer agent reads.
#
# Usage:
#   review-package.sh record-base
#       Record current HEAD as the review base: updates the "- Base sha:" line
#       in docs/smithy/STATE.md. Run BEFORE dispatching an implementor.
#   review-package.sh build <brief-file> <out-file> [implementor-report-file]
#       Build a review package from BASE..HEAD (BASE read from STATE.md —
#       never HEAD~1, which silently drops all but the last commit).
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
    [ $# -ge 3 ] || { echo "usage: review-package.sh build <brief> <out> [impl-report]" >&2; exit 2; }
    brief="$2"; out="$3"; report="${4:-}"
    [ -f "$brief" ] || { echo "review-package.sh: brief not found: $brief" >&2; exit 1; }
    base="$(grep -m1 '^- Base sha:' "$STATE" 2>/dev/null | awk '{print $4}')" || true
    [ -n "${base:-}" ] && [ "$base" != "none" ] || { echo "review-package.sh: no base sha in $STATE — run record-base first" >&2; exit 1; }
    git -C "$PROJECT_ROOT" cat-file -e "$base" 2>/dev/null || { echo "review-package.sh: base sha $base not found in repo" >&2; exit 1; }
    mkdir -p "$(dirname "$out")"
    {
      echo "# Review Package"
      echo
      echo "Base: $base"
      echo "Head: $(git -C "$PROJECT_ROOT" rev-parse HEAD)"
      echo
      echo "## Task Brief"
      echo
      cat "$brief"
      echo
      echo "## Commits ($base..HEAD)"
      echo
      git -C "$PROJECT_ROOT" log --oneline "$base..HEAD"
      echo
      echo "## Diff Stat"
      echo
      git -C "$PROJECT_ROOT" diff --stat "$base..HEAD"
      echo
      echo "## Full Diff (-U10)"
      echo
      git -C "$PROJECT_ROOT" diff -U10 "$base..HEAD"
      if [ -n "$report" ] && [ -f "$report" ]; then
        echo
        echo "## Implementor Report (UNVERIFIED — do not trust; verify every claim)"
        echo
        cat "$report"
      fi
    } > "$out"
    echo "package=$out lines=$(wc -l < "$out")"
    ;;
  *)
    echo "usage: review-package.sh record-base | build <brief> <out> [impl-report]" >&2; exit 2 ;;
esac
