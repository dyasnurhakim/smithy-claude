#!/usr/bin/env bash
# paths.sh — the ONLY place that answers "where does smithy keep things?".
#
# Every other script sources this file (loads it into its own shell) instead
# of working out the repo root itself. So a project whose memory lives OUTSIDE
# the repo works the same in every script.
#
# CLI:
#   paths.sh mem                 memory folder, absolute path (may not exist yet)
#   paths.sh mem-source          which rule found it (see the list below)
#   paths.sh home                global smithy home folder
#   paths.sh root                root of the current worktree
#   paths.sh main-root           root of the MAIN worktree (memory is always found from here)
#   paths.sh slug                stable id for this project (<name>-<hash8>)
#   paths.sh global-config       $SMITHY_HOME/config.json
#   paths.sh project-config      <mem>/config.json
#   paths.sh registry            $SMITHY_HOME/projects.tsv
#   paths.sh lane                active lane name ("" when none)
#   paths.sh lane-source         which rule found the lane
#   paths.sh state-dir           where changing state (STATE, ledger) is written now
#   paths.sh set-mem <dir>       register this project's memory folder (creates it)
#   paths.sh unset-mem           remove this project's line from the registry
#   paths.sh --dump              all of the above, one key=value per line
#
# Sourcing (best inside other scripts — no extra process):
#   . "$(dirname "$0")/paths.sh"        # sets SMITHY_* variables and nothing else
#
# Finding the memory folder — the FIRST rule that matches wins:
#
#   1 env:SMITHY_MEM_DIR       ──▶ set for this session only
#   │ no
#   2 pointer:.smithy-path     ──▶ one-line file at the repo root names the folder
#   │ no
#   3 registry:projects.tsv    ──▶ <abs-main-root> TAB <mem-dir>; nothing in the repo
#   │ no
#   4 existing:docs/smithy     ──▶ an in-repo folder that already exists (old layout)
#   │ no
#   5 default:<repo|external>  ──▶ global memory.location says where a NEW one goes
#     unset:ask                ──▶ memory.location is "ask": the caller must ask the user
#
# The registry is TSV (tab-separated text), not JSON, on purpose. guard.sh
# finds paths before every Bash call, so rules 1-4 must be pure bash and must
# not start an interpreter. Only rule 5 reads JSON, and SMITHY_PATHS_FAST=1
# skips it.
#
# LANES — parallel work that does not clash over shared state.
# $SMITHY_MEM is one folder per PROJECT, tied to the MAIN worktree. Without
# lanes, two pipelines running at once (or the tasks of one parallel forge
# batch) would append to the same ledger.md and overwrite the same STATE.md.
# A lane gives the CHANGING files their own folder: $SMITHY_MEM/lanes/<name>/.
# scripts/lane.sh merges them back when the work lands.
#
# Finding the lane — the FIRST rule that matches wins:
#   1 env:SMITHY_LANE          set for this session or this one dispatch
#   2 marker:.smithy-lane      one-line file at THIS worktree's root. This is
#                              why an agent inside a worktree made by
#                              worktree.sh writes to the right lane without
#                              doing anything itself.
#   3 none                     state-dir == $SMITHY_MEM (normal one-at-a-time work)
#
# A lane name may only use [A-Za-z0-9._-], must not start with a dot, and must
# not contain "..". The name becomes part of a path, so an unchecked name could
# point outside $SMITHY_MEM. A bad name is IGNORED (no lane is used). It is
# never "cleaned up" into a different lane name: quietly writing state to a
# place the caller did not ask for is worse than writing to the shared folder.
#
# What belongs to a lane, and what is shared by the whole project:
#   per lane      STATE.md, ledger.md, decisions.md   (they change as work runs)
#   project-wide  config.json, jobs/, personas/, DESIGN.md, guard tokens
# Config is NOT per lane on purpose: a lane is a piece of work, not a different
# set of settings. jobs/ only gains new files, and their names already carry
# the job slug, so they cannot clash.

# Sourced or run directly? When sourced, never turn on errexit (set -e):
# guard.sh needs a failing grep to NOT stop the shell.
_smithy_paths_sourced=0
(return 0 2>/dev/null) && _smithy_paths_sourced=1
[ "$_smithy_paths_sourced" -eq 0 ] && set -uo pipefail

# Sets a variable instead of printing: this runs before every Bash call, and
# capturing printed output with $(...) would start a subshell each time.
smithy_home() { # -> SMITHY_HOME_DIR
  if [ -n "${SMITHY_HOME:-}" ]; then SMITHY_HOME_DIR="${SMITHY_HOME%/}"
  elif [ -n "${XDG_CONFIG_HOME:-}" ]; then SMITHY_HOME_DIR="${XDG_CONFIG_HOME%/}/smithy"
  else SMITHY_HOME_DIR="$HOME/.smithy"
  fi
}

_smithy_expand() { # _smithy_expand <raw-path> <base-for-relative>
  local p="$1" base="$2"
  case "$p" in
    "~")   p="$HOME" ;;
    "~/"*) p="$HOME/${p#\~/}" ;;
  esac
  case "$p" in /*) ;; *) p="$base/$p" ;; esac
  printf '%s\n' "${p%/}"
}

_smithy_trim() { # remove spaces at both ends (bash builtins only; inner spaces stay)
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

_smithy_hash8() { # _smithy_hash8 <string> — 8 stable hex chars, using whatever tool is installed
  local s="$1" h=""
  if command -v sha1sum >/dev/null 2>&1;   then h="$(printf '%s' "$s" | sha1sum)"
  elif command -v shasum >/dev/null 2>&1;  then h="$(printf '%s' "$s" | shasum)"
  elif command -v md5sum >/dev/null 2>&1;  then h="$(printf '%s' "$s" | md5sum)"
  elif command -v cksum >/dev/null 2>&1;   then h="$(printf '%s' "$s" | cksum | awk '{printf "%08x", $1}')"
  else h="$(printf '%s' "$s" | od -An -tx1 | tr -d ' \n')"
  fi
  printf '%s\n' "$(printf '%s' "${h%% *}" | cut -c1-8)"
}

smithy_roots() { # sets SMITHY_ROOT (this worktree) and SMITHY_MAIN_ROOT (the main one)
  # ONE git call gives both answers. This runs before every Bash call, so a
  # second rev-parse would add ~7ms to each one.
  local out top common
  out="$(git rev-parse --path-format=absolute --show-toplevel --git-common-dir 2>/dev/null)"
  top="${out%%$'\n'*}"
  common="${out#*$'\n'}"
  if [ -n "$top" ] && [ "$top" != "$common" ]; then
    SMITHY_ROOT="$top"
    SMITHY_MAIN_ROOT="$(dirname "$common")"
  else
    SMITHY_ROOT="$PWD"
    SMITHY_MAIN_ROOT="$PWD"
  fi
}

smithy_slug() { # stable project id: dirname + hash of the absolute path
  printf '%s-%s\n' "$(basename "$SMITHY_MAIN_ROOT")" "$(_smithy_hash8 "$SMITHY_MAIN_ROOT")"
}

_smithy_global_location() { # repo | external | ask  (only rule 5 uses this)
  local gc="$SMITHY_HOME_DIR/config.json"
  [ -f "$gc" ] || { echo ask; return 0; }
  command -v python3 >/dev/null 2>&1 || { echo ask; return 0; }
  python3 - "$gc" <<'PY' 2>/dev/null || echo ask
import json, sys
try:
    v = json.load(open(sys.argv[1])).get("memory", {}).get("location", "ask")
except Exception:
    v = "ask"
print(v if v in ("repo", "external", "ask") else "ask")
PY
}

smithy_resolve_mem() { # sets SMITHY_MEM + SMITHY_MEM_SOURCE
  smithy_roots
  smithy_home
  SMITHY_REGISTRY="$SMITHY_HOME_DIR/projects.tsv"

  # 1 — set in the environment
  if [ -n "${SMITHY_MEM_DIR:-}" ]; then
    SMITHY_MEM="$(_smithy_expand "$SMITHY_MEM_DIR" "$SMITHY_MAIN_ROOT")"
    SMITHY_MEM_SOURCE="env:SMITHY_MEM_DIR"
    return 0
  fi

  # 2 — pointer file in the repo (its first line that is not a comment or blank)
  local ptr="$SMITHY_MAIN_ROOT/.smithy-path" line
  if [ -f "$ptr" ]; then
    line="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$ptr" 2>/dev/null | head -1)"
    line="$(_smithy_trim "${line%$'\r'}")"
    if [ -n "$line" ]; then
      SMITHY_MEM="$(_smithy_expand "$line" "$SMITHY_MAIN_ROOT")"
      SMITHY_MEM_SOURCE="pointer:.smithy-path"
      return 0
    fi
  fi

  # 3 — global registry; looked up by the main worktree's absolute root
  if [ -f "$SMITHY_REGISTRY" ]; then
    line="$(awk -F'\t' -v r="$SMITHY_MAIN_ROOT" '$1==r {print $2; exit}' "$SMITHY_REGISTRY" 2>/dev/null)"
    if [ -n "$line" ]; then
      SMITHY_MEM="$(_smithy_expand "$line" "$SMITHY_MAIN_ROOT")"
      SMITHY_MEM_SOURCE="registry:projects.tsv"
      return 0
    fi
  fi

  # 4 — an in-repo folder that already exists beats any default (old layout)
  if [ -d "$SMITHY_MAIN_ROOT/docs/smithy" ]; then
    SMITHY_MEM="$SMITHY_MAIN_ROOT/docs/smithy"
    SMITHY_MEM_SOURCE="existing:docs/smithy"
    return 0
  fi

  # 5 — nothing set: where would a NEW memory folder go?
  if [ "${SMITHY_PATHS_FAST:-0}" = "1" ]; then
    SMITHY_MEM="$SMITHY_MAIN_ROOT/docs/smithy"; SMITHY_MEM_SOURCE="unset:fast"
    return 0
  fi
  case "$(_smithy_global_location)" in
    external) SMITHY_MEM="$SMITHY_HOME_DIR/projects/$(smithy_slug)"; SMITHY_MEM_SOURCE="default:external" ;;
    repo)     SMITHY_MEM="$SMITHY_MAIN_ROOT/docs/smithy";             SMITHY_MEM_SOURCE="default:repo" ;;
    *)        SMITHY_MEM="$SMITHY_MAIN_ROOT/docs/smithy";             SMITHY_MEM_SOURCE="unset:ask" ;;
  esac
}

_smithy_lane_ok() { # a lane name must be safe to use as ONE part of a path
  case "$1" in
    "" | .* | */* | *..*)  return 1 ;;
    *[!A-Za-z0-9._-]*)     return 1 ;;
  esac
  return 0
}

smithy_resolve_lane() { # sets SMITHY_LANE, SMITHY_LANE_SOURCE, SMITHY_STATE_DIR
  local raw="" src="none" line
  SMITHY_LANE_WARN=""

  # 1 — set in the environment (how a dispatcher ties one agent to one lane)
  if [ -n "${SMITHY_LANE:-}" ]; then
    raw="$SMITHY_LANE"; src="env:SMITHY_LANE"

  # 2 — marker at THIS worktree's root, not the main one: each linked
  #     worktree must be able to give a different answer
  elif [ -f "$SMITHY_ROOT/.smithy-lane" ]; then
    line="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$SMITHY_ROOT/.smithy-lane" 2>/dev/null | head -1)"
    line="$(_smithy_trim "${line%$'\r'}")"
    if [ -n "$line" ]; then raw="$line"; src="marker:.smithy-lane"; fi
  fi

  if [ -n "$raw" ] && ! _smithy_lane_ok "$raw"; then
    SMITHY_LANE_WARN="ignoring invalid lane name '$raw' (from $src); using the shared state folder"
    raw=""; src="none"
  fi

  SMITHY_LANE="$raw"
  SMITHY_LANE_SOURCE="$src"
  if [ -n "$raw" ]; then
    SMITHY_STATE_DIR="$SMITHY_MEM/lanes/$raw"
  else
    SMITHY_STATE_DIR="$SMITHY_MEM"
  fi
}

smithy_resolve_mem
smithy_resolve_lane

# `unset:ask` means the location is NOT DECIDED yet. SMITHY_MEM is only a
# guess, and init-memory.sh will not create it until the user picks. Anything
# that only READS memory treats a missing folder as "not set up yet" — correct.
SMITHY_GLOBAL_CONFIG="$SMITHY_HOME_DIR/config.json"
SMITHY_PROJECT_CONFIG="$SMITHY_MEM/config.json"
SMITHY_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMITHY_DEFAULTS="$SMITHY_PLUGIN_ROOT/defaults/config.json"
SMITHY_MODELS="$SMITHY_PLUGIN_ROOT/defaults/models.json"
SMITHY_GLOBAL_MODELS="$SMITHY_HOME_DIR/models.json"

[ "$_smithy_paths_sourced" -eq 1 ] && return 0

# ---------------------------------------------------------------- CLI --------
_registry_write() { # _registry_write <mem-dir|"">  — "" removes this project's line
  local dir="$1" tmp
  mkdir -p "$SMITHY_HOME_DIR"
  tmp="$SMITHY_REGISTRY.tmp.$$"
  : > "$tmp"
  if [ -f "$SMITHY_REGISTRY" ]; then
    awk -F'\t' -v r="$SMITHY_MAIN_ROOT" '$1!=r' "$SMITHY_REGISTRY" >> "$tmp"
  else
    printf '# smithy project registry — <absolute-main-worktree-root>\\t<memory-dir>\n' >> "$tmp"
  fi
  [ -n "$dir" ] && printf '%s\t%s\n' "$SMITHY_MAIN_ROOT" "$dir" >> "$tmp"
  mv "$tmp" "$SMITHY_REGISTRY"
}

case "${1:-}" in
  mem)            echo "$SMITHY_MEM" ;;
  mem-source)     echo "$SMITHY_MEM_SOURCE" ;;
  home)           echo "$SMITHY_HOME_DIR" ;;
  root)           echo "$SMITHY_ROOT" ;;
  main-root)      echo "$SMITHY_MAIN_ROOT" ;;
  slug)           smithy_slug ;;
  global-config)  echo "$SMITHY_GLOBAL_CONFIG" ;;
  project-config) echo "$SMITHY_PROJECT_CONFIG" ;;
  registry)       echo "$SMITHY_REGISTRY" ;;
  lane)           echo "$SMITHY_LANE" ;;
  lane-source)    echo "$SMITHY_LANE_SOURCE" ;;
  state-dir)      echo "$SMITHY_STATE_DIR" ;;
  set-mem)
    [ $# -eq 2 ] || { echo "usage: paths.sh set-mem <dir>" >&2; exit 2; }
    target="$(_smithy_expand "$2" "$SMITHY_MAIN_ROOT")"
    mkdir -p "$target" || { echo "paths.sh: cannot create $target" >&2; exit 1; }
    _registry_write "$target"
    echo "registered: $SMITHY_MAIN_ROOT -> $target"
    echo "(saved in $SMITHY_REGISTRY — nothing was written inside the repo)"
    ;;
  unset-mem)
    [ -f "$SMITHY_REGISTRY" ] || { echo "no registry at $SMITHY_REGISTRY"; exit 0; }
    _registry_write ""
    echo "unregistered: $SMITHY_MAIN_ROOT (the memory folder stays on disk)"
    ;;
  --dump)
    printf 'root=%s\n'           "$SMITHY_ROOT"
    printf 'main_root=%s\n'      "$SMITHY_MAIN_ROOT"
    printf 'slug=%s\n'           "$(smithy_slug)"
    printf 'home=%s\n'           "$SMITHY_HOME_DIR"
    printf 'registry=%s\n'       "$SMITHY_REGISTRY"
    printf 'mem=%s\n'            "$SMITHY_MEM"
    printf 'mem_source=%s\n'     "$SMITHY_MEM_SOURCE"
    printf 'mem_exists=%s\n'     "$([ -d "$SMITHY_MEM" ] && echo yes || echo no)"
    printf 'lane=%s\n'           "${SMITHY_LANE:-}"
    printf 'lane_source=%s\n'    "$SMITHY_LANE_SOURCE"
    printf 'state_dir=%s\n'      "$SMITHY_STATE_DIR"
    # `&& printf` alone would make --dump exit 1 when there is no warning
    [ -n "${SMITHY_LANE_WARN:-}" ] && printf 'lane_warning=%s\n' "$SMITHY_LANE_WARN"
    true
    printf 'global_config=%s\n'  "$SMITHY_GLOBAL_CONFIG"
    printf 'project_config=%s\n' "$SMITHY_PROJECT_CONFIG"
    printf 'defaults=%s\n'       "$SMITHY_DEFAULTS"
    ;;
  -h|--help)
    # Print the whole top comment block. A fixed line range would quietly
    # cut it off each time this header grows.
    awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "${BASH_SOURCE[0]}"
    ;;
  "")
    echo "usage: paths.sh mem|mem-source|home|root|main-root|slug|registry|lane|lane-source|state-dir|set-mem <dir>|unset-mem|--dump" >&2
    exit 2 ;;
  *)
    echo "paths.sh: unknown command '$1' (try --help)" >&2; exit 2 ;;
esac
