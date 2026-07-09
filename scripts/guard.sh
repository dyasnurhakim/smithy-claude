#!/usr/bin/env bash
# guard.sh — smithy guard rails: git safety + destructive-operation protection.
#
#   guard.sh hook                 PreToolUse Bash hook mode: reads the hook JSON
#                                 on stdin, exits 0 (allow) or 2 (block, reason
#                                 on stderr). Enforces ONLY in projects that
#                                 have docs/smithy/ (smithy-managed).
#   guard.sh check "<command>"    Test a command string directly (same rules).
#   guard.sh grant <job>          Authorize `git commit` for this job (written
#                                 at plan-gate approval). File: docs/smithy/.git-grant
#   guard.sh revoke               Remove all grants/tokens (job end / handover).
#   guard.sh allow-push-once      Mint a ONE-SHOT push token (live user yes only).
#   guard.sh allow-once           Mint a ONE-SHOT destructive-command token
#                                 (live user yes only) — permits the NEXT
#                                 otherwise-blocked destructive command (not push).
#   guard.sh status               Show current grant/token state.
#
# Policy (deterministic — prompt rules cannot override this):
#   - git: push needs a one-shot push token; commit needs the job grant;
#     history rewrites and force flags always blocked
#   - destructive ops (filesystem, cloud, IaC, containers, databases) are
#     blocked unless a one-shot destructive token exists (consumed on use)
set -u

# Resolve the MAIN worktree's root (grants/tokens live there — linked
# worktrees created for parallel tasks share the main repo's authorization).
if COMMON="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
  PROJECT_ROOT="$(dirname "$COMMON")"
else
  PROJECT_ROOT="$(pwd)"
fi
MEM="$PROJECT_ROOT/docs/smithy"
GRANT="$MEM/.git-grant"
PUSH_TOKEN="$MEM/.push-once"
DESTRUCTIVE_TOKEN="$MEM/.destructive-once"

block() { echo "[smithy-guard] BLOCKED: $1 Ask the user; after a live yes they can mint a one-shot override (guard.sh allow-once)." >&2; exit 2; }
block_hard() { echo "[smithy-guard] BLOCKED: $1" >&2; exit 2; }

# deny <case-flag> <regex> <message>  — destructive rule with allow-once escape
deny() {
  local flag="$1" re="$2" msg="$3"
  if echo "$CMD" | grep -q"$flag"E "$re"; then
    if [ -f "$DESTRUCTIVE_TOKEN" ]; then
      rm -f "$DESTRUCTIVE_TOKEN"
      echo "[smithy-guard] destructive command allowed — one-shot token consumed ($msg)" >&2
      exit 0
    fi
    block "$msg."
  fi
}

evaluate() { # evaluate <command string>
  CMD="$1"
  # not a smithy-managed project -> no enforcement
  [ -d "$MEM" ] || exit 0

  # ---------- git: push / commit / history (own token & grant mechanics) ----------
  echo "$CMD" | grep -qE 'git[^|;&]*push[^|;&]*(--force|-f\b|--force-with-lease)' && \
    block_hard "force push. Never allowed by smithy guard."
  echo "$CMD" | grep -qE 'git[^|;&]*reset[^|;&]*--hard' && \
    block_hard "git reset --hard. Use git stash or ask the user."
  echo "$CMD" | grep -qE 'git[^|;&]*\brebase\b' && \
    block_hard "git rebase. Ask the user to run it themselves."
  echo "$CMD" | grep -qE 'git[^|;&]*branch[^|;&]* -D\b' && \
    block_hard "git branch -D. Ask the user."
  echo "$CMD" | grep -qE 'git[^|;&]*\bclean\b[^|;&]*-[a-zA-Z]*[fdx]' && \
    block_hard "git clean -f/-d/-x. Ask the user."
  echo "$CMD" | grep -qE 'git[^|;&]*commit[^|;&]*--amend' && \
    block_hard "git commit --amend. History rewrites need the user."
  echo "$CMD" | grep -qE 'git[^|;&]*(filter-branch|update-ref[^|;&]* -d)' && \
    block_hard "git history surgery. Ask the user."

  if echo "$CMD" | grep -qE 'git[^|;&]*\bpush\b'; then
    if [ -f "$PUSH_TOKEN" ]; then
      rm -f "$PUSH_TOKEN"
      echo "[smithy-guard] push allowed — one-shot token consumed." >&2
      exit 0
    fi
    block_hard "git push. Needs a live user yes: run 'guard.sh allow-push-once' ONLY after the user approves this specific push."
  fi
  if echo "$CMD" | grep -qE 'git[^|;&]*\bcommit\b'; then
    [ -f "$GRANT" ] || block_hard "git commit without a grant. Commits are authorized when the user approves the plan gate (guard.sh grant <job>). Ask the user."
  fi

  # ---------- filesystem ----------
  if echo "$CMD" | grep -qE '\brm\b[^|;&]+-([a-zA-Z]*r[a-zA-Z]*f|[a-zA-Z]*f[a-zA-Z]*r)\b'; then
    echo "$CMD" | grep -qE '\brm\b[^|;&]+(-[a-zA-Z]+ +)*(/|~|\.\.)' && \
      deny '' '.' "rm -rf on an absolute/~/.. path"
  fi
  deny ''  '\bfind\b[^|;&]*[[:space:]]-delete\b'                    "find -delete (bulk file deletion)"
  deny ''  '\brsync\b[^|;&]*--delete'                               "rsync --delete (mirrors deletions to the target)"
  deny ''  '\bshred\b'                                              "shred (unrecoverable file destruction)"
  deny ''  '\bmkfs(\.[a-z0-9]+)?\b'                                 "mkfs (formats a filesystem)"
  deny ''  '\bdd\b[^|;&]*\bof=/dev/'                                "dd writing to a raw device"
  deny ''  '\btruncate\b[^|;&]*-s[[:space:]]*0'                     "truncate to zero (destroys file contents)"

  # ---------- cloud CLIs ----------
  deny ''  '\baws\b[^|;&]*\b(terminate-instances|delete-[a-z-]+)\b' "AWS destructive API (terminate/delete-*)"
  deny ''  '\baws\b[^|;&]*\bs3\b[^|;&]*\b(rb|rm)\b'                 "AWS S3 bucket/object deletion"
  deny ''  '\bgcloud\b[^|;&]*\bdelete\b'                            "gcloud delete"
  deny ''  '\bgsutil\b[^|;&]*\b(rm|rb)\b'                           "gsutil rm/rb (GCS deletion)"
  deny ''  '\baz\b[^|;&]*\bdelete\b'                                "az delete"
  deny ''  '\b(flyctl|fly)\b[^|;&]*\b(destroy|apps destroy)\b'      "fly destroy"
  deny ''  '\bheroku\b[^|;&]*\b(destroy|apps:destroy|pg:reset)\b'   "heroku destroy/pg:reset"
  deny ''  '\bvercel\b[^|;&]*\b(remove|rm)\b'                       "vercel remove"
  deny ''  '\bnetlify\b[^|;&]*sites:delete'                         "netlify sites:delete"

  # ---------- infrastructure as code ----------
  deny ''  '\bterraform\b[^|;&]*\bdestroy\b'                        "terraform destroy"
  deny ''  '\bterraform\b[^|;&]*\bapply\b[^|;&]*-destroy'           "terraform apply -destroy"
  deny ''  '\bpulumi\b[^|;&]*\b(destroy|stack rm)\b'                "pulumi destroy / stack rm"
  deny ''  '\bcdk\b[^|;&]*\bdestroy\b'                              "cdk destroy"

  # ---------- containers & orchestration ----------
  deny ''  '\bdocker\b[^|;&]*\b(rm|rmi)\b'                          "docker rm/rmi (deletes containers/images)"
  deny ''  '\bdocker\b[^|;&]*\b(system|volume|container|image|network)\b[^|;&]*\bprune\b' "docker prune (bulk deletion)"
  deny ''  '\bdocker\b[^|;&]*\bvolume\b[^|;&]*\brm\b'               "docker volume rm (deletes data volumes)"
  deny ''  '\bdocker([[:space:]]+|-)compose\b[^|;&]*\bdown\b'       "docker compose down (removes containers; -v removes volumes)"
  deny ''  '\bkubectl\b[^|;&]*\b(delete|drain)\b'                   "kubectl delete/drain"
  deny ''  '\bhelm\b[^|;&]*\b(uninstall|delete|del)\b'              "helm uninstall"

  # ---------- databases ----------
  DB_CTX='\b(psql|mysql|mariadb|sqlite3|mongo(sh)?|redis-cli|clickhouse(-client)?|duckdb|cqlsh)\b'
  deny ''  '\b(dropdb)\b'                                           "dropdb (drops a database)"
  deny ''  '\bmysqladmin\b[^|;&]*\bdrop\b'                          "mysqladmin drop"
  if echo "$CMD" | grep -qE "$DB_CTX"; then
    deny 'i' '\bdrop[[:space:]]+(table|database|schema|collection|user|index|view)\b' "SQL DROP via a database client"
    deny 'i' '\btruncate\b'                                         "SQL TRUNCATE via a database client"
    deny 'i' '\balter[[:space:]]+table\b[^|;&]*\bdrop\b'            "ALTER TABLE ... DROP via a database client"
    if echo "$CMD" | grep -qiE '\bdelete[[:space:]]+from\b' && ! echo "$CMD" | grep -qiE '\bwhere\b'; then
      deny '' '.' "DELETE FROM without a WHERE clause (deletes every row)"
    fi
  fi
  deny ''  '\bredis-cli\b[^|;&]*\bflush(all|db)\b'                  "redis FLUSHALL/FLUSHDB"
  deny 'i' '\bmongo(sh)?\b[^|;&]*(dropDatabase|\.drop\()'           "MongoDB drop"

  # ---------- migration/data resets ----------
  deny ''  '\bprisma\b[^|;&]*\bmigrate\b[^|;&]*\breset\b'           "prisma migrate reset (drops the database)"
  deny ''  '\b(rails|rake)\b[^|;&]*\bdb:(drop|reset|purge)\b'       "rails db:drop/reset/purge"
  deny ''  '\bartisan\b[^|;&]*\bmigrate:(fresh|reset)\b'            "artisan migrate:fresh/reset"
  deny ''  '\bmanage\.py\b[^|;&]*\b(flush|reset_db|sqlflush)\b'     "Django flush/reset_db"
  deny ''  '\balembic\b[^|;&]*\bdowngrade\b[^|;&]*\bbase\b'         "alembic downgrade base"
  deny ''  '\bnpm\b[^|;&]*\bunpublish\b'                            "npm unpublish"

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
    rm -f "$GRANT" "$PUSH_TOKEN" "$DESTRUCTIVE_TOKEN"
    echo "grants revoked"
    ;;
  allow-push-once)
    mkdir -p "$MEM"
    date -u +%Y-%m-%dT%H:%MZ > "$PUSH_TOKEN"
    echo "one-shot push token minted ($PUSH_TOKEN) — consumed by the next push"
    ;;
  allow-once)
    mkdir -p "$MEM"
    date -u +%Y-%m-%dT%H:%MZ > "$DESTRUCTIVE_TOKEN"
    echo "one-shot destructive-command token minted ($DESTRUCTIVE_TOKEN) — consumed by the next blocked destructive command (push excluded)"
    ;;
  status)
    [ -f "$GRANT" ] && { echo "commit grant:"; sed 's/^/  /' "$GRANT"; } || echo "commit grant: none"
    [ -f "$PUSH_TOKEN" ] && echo "push token: present (one-shot)" || echo "push token: none"
    [ -f "$DESTRUCTIVE_TOKEN" ] && echo "destructive token: present (one-shot)" || echo "destructive token: none"
    ;;
  *)
    echo "usage: guard.sh hook|check|grant|revoke|allow-push-once|allow-once|status" >&2; exit 3 ;;
esac
