#!/usr/bin/env bash
# guard.sh — smithy's safety guard for git and destructive commands.
#
#   guard.sh hook                 Hook mode. Claude Code runs it before EVERY
#                                 Bash call (a PreToolUse hook). Reads the hook
#                                 JSON on stdin. Exit 0 = allow, exit 2 = block
#                                 (the reason goes to stderr). It acts ONLY in
#                                 smithy-managed projects: those whose smithy
#                                 memory folder exists, wherever paths.sh finds it.
#   guard.sh check "<command>"    Test one command string. Same rules.
#   guard.sh grant <job>          Allow `git commit` for this job. Written when
#                                 the user approves the plan gate.
#                                 File: <mem>/.git-grant
#   guard.sh revoke               Remove every grant and token (job end / handover).
#   guard.sh allow-push-once      Make a ONE-USE push token. Only after a live user yes.
#   guard.sh allow-once           Make a ONE-USE destructive-command token. Only
#                                 after a live user yes. It lets the NEXT blocked
#                                 destructive command run (never a push).
#   guard.sh status               Show which grant and tokens exist now.
#
# Rules (fixed in code — a prompt cannot change them):
#
#   command                              allowed when
#   ───────────────────────────────────  ──────────────────────────────────
#   git push                             a push token exists (one push uses it up)
#   git commit                           the job's commit grant exists
#   force push, reset --hard, rebase,    never — always blocked
#   commit --amend, other history edits
#   destructive: files, cloud, IaC       a destructive token exists
#   (infrastructure as code),            (one command uses it up)
#   containers, databases
set -u

# Grants and tokens live in the MAIN worktree's memory folder. Linked worktrees
# (made for parallel tasks) share the main repo's grants. paths.sh finds that
# folder wherever it lives (it need not be inside the repo).
#
# SMITHY_PATHS_FAST=1 keeps path lookup in pure bash. This script runs before
# EVERY Bash call, so it must not start an interpreter (like python).
# Fast mode skips only one rule: "where would a NEW folder go". That rule cannot
# matter here. init-memory.sh records every non-default location in
# projects.tsv, and a folder that is not found means "not smithy-managed",
# so the guard does nothing.
SMITHY_PATHS_FAST=1
# shellcheck source=./paths.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/paths.sh"
MEM="$SMITHY_MEM"
GRANT="$MEM/.git-grant"
PUSH_TOKEN="$MEM/.push-once"
DESTRUCTIVE_TOKEN="$MEM/.destructive-once"

block() { echo "[smithy-guard] BLOCKED: $1 Ask the user. Only after a live yes, run 'guard.sh allow-once' to allow this one command." >&2; exit 2; }
block_hard() { echo "[smithy-guard] BLOCKED: $1" >&2; exit 2; }

# deny <case-flag> <regex> <message> — one destructive-command rule.
# A destructive token (from allow-once) lets one match through, then is deleted.
deny() {
  local flag="$1" re="$2" msg="$3"
  if echo "$CMD" | grep -q"$flag"E "$re"; then
    if [ -f "$DESTRUCTIVE_TOKEN" ]; then
      rm -f "$DESTRUCTIVE_TOKEN"
      echo "[smithy-guard] destructive command allowed — the one-use token is now used up ($msg)" >&2
      exit 0
    fi
    block "$msg."
  fi
}

evaluate() { # evaluate <command string>
  CMD="$1"
  # Not a smithy-managed project -> do nothing.
  [ -d "$MEM" ] || exit 0

  # ---------- git: push / commit / history (push token and commit grant) ----------
  echo "$CMD" | grep -qE 'git[^|;&]*push[^|;&]*(--force|-f\b|--force-with-lease)' && \
    block_hard "force push. Never allowed."
  echo "$CMD" | grep -qE 'git[^|;&]*reset[^|;&]*--hard' && \
    block_hard "git reset --hard. Use git stash or ask the user."
  echo "$CMD" | grep -qE 'git[^|;&]*\brebase\b' && \
    block_hard "git rebase. Ask the user to run it themselves."
  echo "$CMD" | grep -qE 'git[^|;&]*branch[^|;&]* -D\b' && \
    block_hard "git branch -D. Ask the user."
  echo "$CMD" | grep -qE 'git[^|;&]*\bclean\b[^|;&]*-[a-zA-Z]*[fdx]' && \
    block_hard "git clean -f/-d/-x. Ask the user."
  echo "$CMD" | grep -qE 'git[^|;&]*commit[^|;&]*--amend' && \
    block_hard "git commit --amend. Only the user may rewrite history."
  echo "$CMD" | grep -qE 'git[^|;&]*(filter-branch|update-ref[^|;&]* -d)' && \
    block_hard "git history rewrite (filter-branch / update-ref -d). Ask the user."

  if echo "$CMD" | grep -qE 'git[^|;&]*\bpush\b'; then
    if [ -f "$PUSH_TOKEN" ]; then
      rm -f "$PUSH_TOKEN"
      echo "[smithy-guard] push allowed — the one-use token is now used up." >&2
      exit 0
    fi
    block_hard "git push. Needs a live user yes for THIS push. Only then run 'guard.sh allow-push-once'."
  fi
  if echo "$CMD" | grep -qE 'git[^|;&]*\bcommit\b'; then
    [ -f "$GRANT" ] || block_hard "git commit with no grant. Commits are allowed once the user approves the plan gate (guard.sh grant <job>). Ask the user."
  fi

  # ---------- filesystem ----------
  if echo "$CMD" | grep -qE '\brm\b[^|;&]+-([a-zA-Z]*r[a-zA-Z]*f|[a-zA-Z]*f[a-zA-Z]*r)\b'; then
    echo "$CMD" | grep -qE '\brm\b[^|;&]+(-[a-zA-Z]+ +)*(/|~|\.\.)' && \
      deny '' '.' "rm -rf on a path that starts with /, ~ or .."
  fi
  deny ''  '\bfind\b[^|;&]*[[:space:]]-delete\b'                    "find -delete (bulk file deletion)"
  deny ''  '\brsync\b[^|;&]*--delete'                               "rsync --delete (also deletes files on the target)"
  deny ''  '\bshred\b'                                              "shred (destroys files for good)"
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

  # ---------- infrastructure as code (IaC) ----------
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

  # ---------- migration and data resets ----------
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
    echo "one-use push token made ($PUSH_TOKEN) — the next push uses it up"
    ;;
  allow-once)
    mkdir -p "$MEM"
    date -u +%Y-%m-%dT%H:%MZ > "$DESTRUCTIVE_TOKEN"
    echo "one-use destructive-command token made ($DESTRUCTIVE_TOKEN) — the next blocked destructive command uses it up (never a push)"
    ;;
  status)
    [ -f "$GRANT" ] && { echo "commit grant:"; sed 's/^/  /' "$GRANT"; } || echo "commit grant: none"
    [ -f "$PUSH_TOKEN" ] && echo "push token: present (one-use)" || echo "push token: none"
    [ -f "$DESTRUCTIVE_TOKEN" ] && echo "destructive token: present (one-use)" || echo "destructive token: none"
    ;;
  *)
    echo "usage: guard.sh hook|check|grant|revoke|allow-push-once|allow-once|status" >&2; exit 3 ;;
esac
