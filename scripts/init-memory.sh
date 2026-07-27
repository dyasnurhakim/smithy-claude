#!/usr/bin/env bash
# init-memory.sh — idempotently scaffold this project's smithy memory dir.
# Creates only what is missing; prints each item it created.
#
# The memory dir does NOT have to live in the repo. Resolution order is
# paths.sh's (env -> .smithy-path -> registry -> existing docs/smithy -> global
# default). When nothing is configured and the global default is "ask", this
# script REFUSES to guess and exits 3 — the caller asks the user, then re-runs
# with one of:
#
#   init-memory.sh --in-repo          <repo>/docs/smithy          (committable)
#   init-memory.sh --external         $SMITHY_HOME/projects/<slug> (outside the repo)
#   init-memory.sh --at <dir>         any directory you name
#   init-memory.sh --at <dir> --pointer
#                                     ...plus a .smithy-path file at the repo
#                                     root so a fresh clone finds it too
#
# --in-repo/--external/--at also RELOCATE an existing setup's registration;
# they never move files. Use `--global-default repo|external|ask` to stop being
# asked for future projects.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"

CHOICE=""; AT=""; POINTER=0; GLOBAL_DEFAULT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --in-repo)  CHOICE="repo" ;;
    --external) CHOICE="external" ;;
    --at)       CHOICE="at"; AT="${2:-}"; shift
                [ -n "$AT" ] || { echo "init-memory.sh: --at needs a directory" >&2; exit 2; } ;;
    --pointer)  POINTER=1 ;;
    --global-default)
                GLOBAL_DEFAULT="${2:-}"; shift
                case "$GLOBAL_DEFAULT" in repo|external|ask) ;;
                  *) echo "init-memory.sh: --global-default must be repo|external|ask" >&2; exit 2 ;; esac ;;
    -h|--help)  sed -n '2,26p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          echo "init-memory.sh: unknown argument '$1' (try --help)" >&2; exit 2 ;;
  esac
  shift
done

if [ -n "$GLOBAL_DEFAULT" ]; then
  bash "$SCRIPT_DIR/config.sh" set global memory.location "$GLOBAL_DEFAULT" >/dev/null \
    && echo "global default for NEW projects: memory.location=$GLOBAL_DEFAULT"
fi

# ---- decide the location -----------------------------------------------------
case "$CHOICE" in
  repo)     TARGET="$SMITHY_MAIN_ROOT/docs/smithy" ;;
  external) TARGET="$SMITHY_HOME_DIR/projects/$(smithy_slug)" ;;
  at)       TARGET="$(_smithy_expand "$AT" "$SMITHY_MAIN_ROOT")" ;;
  "")
    if [ "$SMITHY_MEM_SOURCE" = "unset:ask" ]; then
      cat >&2 <<EOF
init-memory.sh: WHERE this project keeps smithy memory is undecided — refusing to guess.

  ASK THE USER, then re-run with their choice:
    --in-repo     $SMITHY_MAIN_ROOT/docs/smithy
                  (committable, reviewable alongside the code; wrong if this
                   repo cleans or regenerates docs/)
    --external    $SMITHY_HOME_DIR/projects/$(smithy_slug)
                  (survives any repo cleaning; not committed, not shared)
    --at <dir>    somewhere you name (add --pointer to record it in-repo)

  Add --global-default repo|external to skip this question in future projects.
EOF
      exit 3
    fi
    TARGET="$SMITHY_MEM"
    ;;
esac

# ---- register + create -------------------------------------------------------
INSIDE=0
case "$TARGET/" in "$SMITHY_MAIN_ROOT"/*) INSIDE=1 ;; esac

created=0
mk() { echo "created: $1"; created=1; }

mkdir -p "$TARGET" || { echo "init-memory.sh: cannot create $TARGET" >&2; exit 1; }

# Register anything that is NOT the legacy in-repo default. The invariant that
# every non-default location is in the registry is what lets guard.sh resolve
# paths on the hook path in pure bash (SMITHY_PATHS_FAST) without missing one.
if [ "$TARGET" != "$SMITHY_MAIN_ROOT/docs/smithy" ]; then
  bash "$SCRIPT_DIR/paths.sh" set-mem "$TARGET" >/dev/null
  echo "registered: $SMITHY_MAIN_ROOT -> $TARGET"
elif [ -n "$CHOICE" ]; then
  bash "$SCRIPT_DIR/paths.sh" unset-mem >/dev/null 2>&1 || true
fi

if [ "$POINTER" -eq 1 ]; then
  PTR="$SMITHY_MAIN_ROOT/.smithy-path"
  if [ ! -f "$PTR" ]; then
    printf '# smithy memory dir for this project (see scripts/paths.sh)\n%s\n' "$TARGET" > "$PTR"
    mk "$PTR"
  else
    echo "note: $PTR already exists — left untouched (edit it by hand to repoint)"
  fi
fi

MEM="$TARGET"

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

[ -d "$MEM/jobs" ]         || { mkdir -p "$MEM/jobs"; mk "$MEM/jobs/"; }
[ -f "$MEM/ledger.md" ]    || { : > "$MEM/ledger.md"; mk "$MEM/ledger.md"; }
[ -f "$MEM/decisions.md" ] || { printf '# Decisions\n' > "$MEM/decisions.md"; mk "$MEM/decisions.md"; }

# guard tokens must never be committed — only meaningful when memory is in-repo
if [ "$INSIDE" -eq 1 ] && [ ! -f "$MEM/.gitignore" ]; then
  printf '.git-grant\n.push-once\n.destructive-once\n' > "$MEM/.gitignore"
  mk "$MEM/.gitignore"
fi

# Out-of-repo dirs get a breadcrumb — $SMITHY_HOME/projects/ is otherwise opaque
if [ "$INSIDE" -eq 0 ] && [ ! -f "$MEM/PROJECT.md" ]; then
  printf '# Smithy memory\n\n- Project: %s\n- Created: %s\n- Registry: %s\n' \
    "$SMITHY_MAIN_ROOT" "$(date -u +%Y-%m-%dT%H:%MZ)" "$SMITHY_REGISTRY" > "$MEM/PROJECT.md"
  mk "$MEM/PROJECT.md"
fi

# Project config starts SPARSE — it holds only overrides; the config layers
# merge it over global and then plugin defaults. Copying the full defaults here
# would pin stale values and make every role read as "project"-sourced.
if [ ! -f "$MEM/config.json" ]; then
  printf '{\n  "smithy_config_version": 1,\n  "routing": {}\n}\n' > "$MEM/config.json"
  mk "$MEM/config.json"
fi

echo "memory: $MEM"
[ "$created" -eq 0 ] && echo "(already initialized — nothing created)"
exit 0
