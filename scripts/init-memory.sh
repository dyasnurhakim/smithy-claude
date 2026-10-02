#!/usr/bin/env bash
# init-memory.sh — set up this project's smithy memory folder. Safe to run
# again: it creates only what is missing and prints each item it creates.
#
# The memory folder does NOT have to be in the repo. It is found in paths.sh
# order (env -> .smithy-path -> registry -> existing docs/smithy -> global
# default). If nothing is set and the global default is "ask", this script
# will NOT guess: it exits 3. The caller asks the user, then runs it again
# with one of:
#
#   init-memory.sh --in-repo          <repo>/docs/smithy          (can be committed)
#   init-memory.sh --external         $SMITHY_HOME/projects/<slug> (outside the repo)
#   init-memory.sh --at <dir>         any folder you name
#   init-memory.sh --at <dir> --pointer
#                                     ...plus a .smithy-path file at the repo
#                                     root, so a fresh clone finds it too
#
# On an existing setup, --in-repo / --external / --at only CHANGE where it is
# registered; they never move files. `--global-default repo|external|ask`
# sets the answer for future projects, so you are not asked again.
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
                [ -n "$AT" ] || { echo "init-memory.sh: --at needs a folder path" >&2; exit 2; } ;;
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
init-memory.sh: WHERE this project keeps smithy memory is not decided yet — not guessing.

  ASK THE USER, then run again with their choice:
    --in-repo     $SMITHY_MAIN_ROOT/docs/smithy
                  (can be committed and reviewed with the code; a bad choice
                   if this repo cleans or rebuilds docs/)
    --external    $SMITHY_HOME_DIR/projects/$(smithy_slug)
                  (safe from any repo cleaning; not committed, not shared)
    --at <dir>    a place you name (add --pointer to save the path in the repo)

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

# Register every location that is NOT the old in-repo default. Because every
# other location is always in the registry, guard.sh can find paths in pure
# bash before each Bash call (SMITHY_PATHS_FAST) and never miss one.
if [ "$TARGET" != "$SMITHY_MAIN_ROOT/docs/smithy" ]; then
  bash "$SCRIPT_DIR/paths.sh" set-mem "$TARGET" >/dev/null
  echo "registered: $SMITHY_MAIN_ROOT -> $TARGET"
elif [ -n "$CHOICE" ]; then
  bash "$SCRIPT_DIR/paths.sh" unset-mem >/dev/null 2>&1 || true
fi

if [ "$POINTER" -eq 1 ]; then
  PTR="$SMITHY_MAIN_ROOT/.smithy-path"
  if [ ! -f "$PTR" ]; then
    printf '# smithy memory folder for this project (see scripts/paths.sh)\n%s\n' "$TARGET" > "$PTR"
    mk "$PTR"
  else
    echo "note: $PTR already exists — not changed (edit it by hand to point somewhere else)"
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

# Guard tokens must never be committed. This only matters when memory is in the repo.
if [ "$INSIDE" -eq 1 ] && [ ! -f "$MEM/.gitignore" ]; then
  printf '.git-grant\n.push-once\n.destructive-once\n' > "$MEM/.gitignore"
  mk "$MEM/.gitignore"
fi

# A folder outside the repo gets a PROJECT.md that says which repo it belongs
# to — otherwise $SMITHY_HOME/projects/ is hard to read.
if [ "$INSIDE" -eq 0 ] && [ ! -f "$MEM/PROJECT.md" ]; then
  printf '# Smithy memory\n\n- Project: %s\n- Created: %s\n- Registry: %s\n' \
    "$SMITHY_MAIN_ROOT" "$(date -u +%Y-%m-%dT%H:%MZ)" "$SMITHY_REGISTRY" > "$MEM/PROJECT.md"
  mk "$MEM/PROJECT.md"
fi

# Project config starts almost EMPTY. It holds only overrides; the config
# layers put it on top of global, then plugin defaults. Copying all defaults
# here would freeze old values and make every role look "project"-set.
if [ ! -f "$MEM/config.json" ]; then
  printf '{\n  "smithy_config_version": 1,\n  "routing": {}\n}\n' > "$MEM/config.json"
  mk "$MEM/config.json"
fi

echo "memory: $MEM"
[ "$created" -eq 0 ] && echo "(already set up — nothing created)"
exit 0
