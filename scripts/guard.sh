#!/usr/bin/env bash
# guard.sh — smithy git guard rails.
#
#   guard.sh hook                 PreToolUse Bash hook mode: reads the hook JSON
#                                 on stdin, exits 0 (allow) or 2 (block, reason
#                                 on stderr). Enforces ONLY in projects that
#                                 have docs/smithy/ (smithy-managed).
#   guard.sh check "<command>"    Test a command string directly (same rules).
#   guard.sh grant <job>          Authorize `git commit` for this job (written
#                                 at plan-gate approval). File: docs/smithy/.git-grant
#   guard.sh revoke               Remove the commit grant (job end / handover).
#   guard.sh allow-push-once      Mint a ONE-SHOT push token (live user yes only).
#   guard.sh status               Show current grant/token state.
#
# Policy (deterministic — prompt rules cannot override this):
#   - blocked always: git push --force/-f, reset --hard, rebase, branch -D,
#     clean -f/-d/-x, commit --amend, filter-branch, update-ref -d,
#     `rm -rf` on absolute / ~ / .. paths
#   - git push: blocked unless a one-shot token exists (consumed on use)
#   - git commit: blocked unless docs/smithy/.git-grant exists
#   - everything else: allowed
set -u

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MEM="$PROJECT_ROOT/docs/smithy"
GRANT="$MEM/.git-grant"
PUSH_TOKEN="$MEM/.push-once"

block() { echo "[smithy-guard] BLOCKED: $1" >&2; exit 2; }

evaluate() { # evaluate <command string>
  local cmd="$1"
  # not a smithy-managed project -> no enforcement
  [ -d "$MEM" ] || exit 0
  # only inspect commands that mention git or rm at all (fast path out)
  case "$cmd" in *git*|*rm\ *) ;; *) exit 0 ;; esac

  # --- destructive: always blocked ---
  echo "$cmd" | grep -qE 'git[^|;&]*push[^|;&]*(--force|-f\b|--force-with-lease)' && \
    block "force push. Never allowed by smithy guard."
  echo "$cmd" | grep -qE 'git[^|;&]*reset[^|;&]*--hard' && \
    block "git reset --hard. Use git stash or ask the user."
  echo "$cmd" | grep -qE 'git[^|;&]*\brebase\b' && \
    block "git rebase. Ask the user to run it themselves."
  echo "$cmd" | grep -qE 'git[^|;&]*branch[^|;&]* -D\b' && \
    block "git branch -D. Ask the user."
  echo "$cmd" | grep -qE 'git[^|;&]*\bclean\b[^|;&]*-[a-zA-Z]*[fdx]' && \
    block "git clean -f/-d/-x. Ask the user."
  echo "$cmd" | grep -qE 'git[^|;&]*commit[^|;&]*--amend' && \
    block "git commit --amend. History rewrites need the user."
  echo "$cmd" | grep -qE 'git[^|;&]*(filter-branch|update-ref[^|;&]* -d)' && \
    block "git history surgery. Ask the user."
  if echo "$cmd" | grep -qE '\brm\b[^|;&]+-([a-zA-Z]*r[a-zA-Z]*f|[a-zA-Z]*f[a-zA-Z]*r)\b'; then
    echo "$cmd" | grep -qE '\brm\b[^|;&]+(-[a-zA-Z]+ +)*(/|~|\.\.)' && \
      block "rm -rf on an absolute/~/.. path. Scope deletions inside the project and ask first."
  fi

  # --- push: one-shot token ---
  if echo "$cmd" | grep -qE 'git[^|;&]*\bpush\b'; then
    if [ -f "$PUSH_TOKEN" ]; then
      rm -f "$PUSH_TOKEN"
      echo "[smithy-guard] push allowed — one-shot token consumed." >&2
      exit 0
    fi
    block "git push. Needs a live user yes: run 'guard.sh allow-push-once' ONLY after the user approves this specific push."
  fi

  # --- commit: job-scoped grant ---
  if echo "$cmd" | grep -qE 'git[^|;&]*\bcommit\b'; then
    [ -f "$GRANT" ] && exit 0
    block "git commit without a grant. Commits are authorized when the user approves the plan gate (guard.sh grant <job>). Ask the user."
  fi

  exit 0
}

case "${1:-}" in
  hook)
    cmd="$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: print("")' 2>/dev/null || true)"
    [ -n "$cmd" ] || exit 0
    evaluate "$cmd"
    ;;
  check)
    [ $# -eq 2 ] || { echo "usage: guard.sh check \"<command>\"" >&2; exit 3; }
    evaluate "$2"
    ;;
  grant)
    [ $# -eq 2 ] || { echo "usage: guard.sh grant <job>" >&2; exit 3; }
    mkdir -p "$MEM"
    printf 'job: %s\ngranted: %s\nscope: commit\n' "$2" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$GRANT"
    echo "commit grant written for job '$2' ($GRANT)"
    ;;
  revoke)
    rm -f "$GRANT" "$PUSH_TOKEN"
    echo "grants revoked"
    ;;
  allow-push-once)
    mkdir -p "$MEM"
    date -u +%Y-%m-%dT%H:%MZ > "$PUSH_TOKEN"
    echo "one-shot push token minted ($PUSH_TOKEN) — consumed by the next push"
    ;;
  status)
    [ -f "$GRANT" ] && { echo "commit grant:"; sed 's/^/  /' "$GRANT"; } || echo "commit grant: none"
    [ -f "$PUSH_TOKEN" ] && echo "push token: present (one-shot)" || echo "push token: none"
    ;;
  *)
    echo "usage: guard.sh hook|check|grant|revoke|allow-push-once|status" >&2; exit 3 ;;
esac
