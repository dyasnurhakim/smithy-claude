#!/usr/bin/env bash
#
# sync-to-codex-plugin.sh — package smithy for the official Codex plugin
# marketplace (github.com/openai/plugins) and optionally open the submission PR.
#
# The Codex marketplace hosts each plugin at plugins/<name>/ inside that repo;
# listing requires a PR. This script stages the canonical plugin tree (what
# Codex actually needs — including smithy's FUNCTIONAL scripts/, references/,
# defaults/, agents/, unlike repo-infra-only projects) and can sync it into
# your fork and open the PR.
#
# Usage:
#   ./scripts/sync-to-codex-plugin.sh --stage-only [DIR]   # build the plugin tree locally (default: ./build/codex-plugin)
#   ./scripts/sync-to-codex-plugin.sh --fork OWNER/REPO    # full run: clone fork, sync, branch, push, PR
#   ./scripts/sync-to-codex-plugin.sh --fork OWNER/REPO -n # dry run (no push/PR)
#
# Requires: bash, rsync, git; gh (authenticated) for the PR path.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM="openai/plugins"
DEST_REL="plugins/smithy"
VERSION="$(python3 -c "import json;print(json.load(open('$SRC/.codex-plugin/plugin.json'))['version'])")"

# What the Codex plugin ships. Smithy's scripts/references/defaults/agents are
# FUNCTIONAL (routing, guard, ledger, envelope, personas) — they must ship.
INCLUDES=(
  ".codex-plugin/"
  "skills/"
  "agents/"
  "references/"
  "defaults/"
  "scripts/"
  "README.md"
  "LICENSE"
)
# Never ship: other harnesses' dirs, repo infra, Claude-format aliases, hooks
# (Codex runs none — .codex-plugin/plugin.json declares hooks:{} on purpose),
# repo ceremony (CLAUDE.md/AGENTS.md — marketplace installs surface skills
# natively; the AGENTS.md bootstrap is only for plain clones).
EXCLUDES=(
  "/scripts/sync-to-codex-plugin.sh"
  ".DS_Store"
)

stage() { # stage <dest-dir>
  local dest="$1"
  rm -rf "$dest"; mkdir -p "$dest"
  local args=(-aR)   # -R: preserve the relative paths of each include
  for e in "${EXCLUDES[@]}"; do args+=(--exclude "$e"); done
  (cd "$SRC" && rsync "${args[@]}" "${INCLUDES[@]}" "$dest/")
  # Codex reads plugin.json from the plugin root
  cp "$SRC/.codex-plugin/plugin.json" "$dest/plugin.json"
  echo "staged smithy v$VERSION → $dest"
  echo "tree:"; (cd "$dest" && find . -maxdepth 1 | sort | sed 's/^/  /')
}

case "${1:-}" in
  --stage-only)
    stage "${2:-$SRC/build/codex-plugin}"
    ;;
  --fork)
    [ $# -ge 2 ] || { echo "usage: $0 --fork OWNER/REPO [-n]" >&2; exit 2; }
    FORK="$2"; DRY="${3:-}"
    command -v gh >/dev/null || { echo "gh CLI required for the PR path" >&2; exit 1; }
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    echo "cloning fork $FORK…"
    gh repo clone "$FORK" "$TMP/fork" -- --depth 1 >/dev/null 2>&1
    stage "$TMP/fork/$DEST_REL"
    cd "$TMP/fork"
    BRANCH="sync-smithy-v$VERSION"
    git checkout -b "$BRANCH" >/dev/null 2>&1
    git add "$DEST_REL"
    if git diff --cached --quiet; then echo "no changes vs fork — nothing to sync"; exit 0; fi
    git commit -m "smithy v$VERSION: sync from dyasnurhakim/smithy-claude" >/dev/null
    if [ "$DRY" = "-n" ]; then
      echo "DRY RUN — would push $BRANCH to $FORK and open a PR against $UPSTREAM"
      git show --stat HEAD | head -20
    else
      git push -u origin "$BRANCH"
      gh pr create --repo "$UPSTREAM" --head "${FORK%%/*}:$BRANCH" \
        --title "Add/update smithy v$VERSION" \
        --body "Full dev-pipeline plugin (research/planning/TDD/persona review/debugging/testing). Synced from https://github.com/dyasnurhakim/smithy-claude"
      echo "PR opened against $UPSTREAM"
    fi
    ;;
  *)
    echo "usage: $0 --stage-only [DIR] | --fork OWNER/REPO [-n]" >&2; exit 2 ;;
esac
