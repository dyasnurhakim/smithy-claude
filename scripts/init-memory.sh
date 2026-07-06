#!/usr/bin/env bash
# init-memory.sh — idempotently scaffold docs/smithy/ in the current project.
# Creates only what is missing; prints each item it created.
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
MEM="$PROJECT_ROOT/docs/smithy"

created=0
mk() { echo "created: ${1#"$PROJECT_ROOT"/}"; created=1; }

[ -d "$MEM/jobs" ] || { mkdir -p "$MEM/jobs"; mk "$MEM/jobs/"; }

if [ ! -f "$MEM/STATE.md" ]; then
  cat > "$MEM/STATE.md" <<'EOF'
# Smithy State
- Active job: none
- Phase: IDLE
- Base sha: none
- Last event: (none)
- Blockers: none
- Next step: run /smithy:assay to start a job
EOF
  mk "$MEM/STATE.md"
fi

[ -f "$MEM/ledger.md" ]    || { : > "$MEM/ledger.md"; mk "$MEM/ledger.md"; }

# guard tokens must never be committed
if [ ! -f "$MEM/.gitignore" ]; then
  printf '.git-grant\n.push-once\n' > "$MEM/.gitignore"
  mk "$MEM/.gitignore"
fi
[ -f "$MEM/decisions.md" ] || { printf '# Decisions\n' > "$MEM/decisions.md"; mk "$MEM/decisions.md"; }

# Project config starts SPARSE — it holds only overrides; routing.sh merges it
# over the plugin defaults. Copying the full defaults here would pin stale
# values and make every role read as "project"-sourced.
if [ ! -f "$MEM/config.json" ]; then
  printf '{\n  "smithy_config_version": 1,\n  "routing": {}\n}\n' > "$MEM/config.json"
  mk "$MEM/config.json"
fi

[ "$created" -eq 0 ] && echo "docs/smithy/ already initialized (nothing created)"
exit 0
