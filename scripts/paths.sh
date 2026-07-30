#!/usr/bin/env bash
# paths.sh — the ONLY place that answers "where does smithy keep things?".
#
# Every other script sources this instead of re-deriving the repo root, so a
# project whose memory lives OUTSIDE the repo works everywhere at once.
#
# CLI:
#   paths.sh mem                 absolute memory dir (may not exist yet)
#   paths.sh mem-source          which rule resolved it (see table below)
#   paths.sh home                global smithy home
#   paths.sh root                current worktree root
#   paths.sh main-root           MAIN worktree root (memory always resolves here)
#   paths.sh slug                stable id for this project (<name>-<hash8>)
#   paths.sh global-config       $SMITHY_HOME/config.json
#   paths.sh project-config      <mem>/config.json
#   paths.sh registry            $SMITHY_HOME/projects.tsv
#   paths.sh lane                active lane name ("" when none)
#   paths.sh lane-source         which rule resolved the lane
#   paths.sh state-dir           where MUTABLE state is written right now
#   paths.sh set-mem <dir>       register this project's memory dir (creates it)
#   paths.sh unset-mem           drop this project's registry entry
#   paths.sh --dump              everything above, one key=value per line
#
# Sourcing (preferred inside other scripts — no subprocess):
#   . "$(dirname "$0")/paths.sh"        # defines SMITHY_* vars, sets nothing else
#
# Memory-dir resolution — FIRST MATCH WINS:
#   1 env:SMITHY_MEM_DIR       explicit per-session override
#   2 pointer:.smithy-path     one-line pointer file at the repo root
#   3 registry:projects.tsv    <abs-main-root> TAB <mem-dir>, fully outside the repo
#   4 existing:docs/smithy     back-compat: an in-repo dir that already exists
#   5 default:<repo|external>  global memory.location decides where a NEW one goes
#     unset:ask                global memory.location is "ask" -> caller must ask
#
# The registry is TSV, not JSON, on purpose: guard.sh resolves paths on the
# PreToolUse hook path, so rules 1-4 must be pure bash with no interpreter
# spawn. Only rule 5 reads JSON, and SMITHY_PATHS_FAST=1 skips it.
#
# LANES — parallel work without a shared-state collision.
# $SMITHY_MEM is one directory per PROJECT, anchored on the MAIN worktree, so
# two concurrent pipelines (or the tasks of one parallel forge batch) would
# otherwise append to the same ledger.md and overwrite the same STATE.md. A
# lane namespaces exactly the MUTABLE files under $SMITHY_MEM/lanes/<name>/;
# scripts/lane.sh merges them back when the work lands.
#
# Lane resolution — FIRST MATCH WINS:
#   1 env:SMITHY_LANE          explicit per-session/per-dispatch override
#   2 marker:.smithy-lane      one-line file at THIS worktree's root — which is
#                              why an agent working inside a worktree created by
#                              worktree.sh lands in the right lane with no
#                              cooperation of its own
#   3 none                     state-dir == $SMITHY_MEM (normal serial work)
#
# Lane names are restricted to [A-Za-z0-9._-] with no leading dot and no "..":
# the name becomes a path segment, so an unvalidated one would escape $SMITHY_MEM.
# An invalid name is IGNORED (falls back to no lane) rather than being sanitised
# into a different lane — silently writing state somewhere the caller did not
# ask for is worse than writing it to the shared root.
#
# What is lane-scoped vs project-wide:
#   lane-scoped   STATE.md, ledger.md, decisions.md   (mutable, per-unit)
#   project-wide  config.json, jobs/, personas/, DESIGN.md, guard tokens
# Config is deliberately NOT lane-scoped — a lane is a unit of work, not a
# different set of preferences, and jobs/ holds append-only artifacts whose
# filenames already carry the job slug.

# Sourced or executed? Never enable errexit when sourced — guard.sh relies on
# failing greps not killing the shell.
_smithy_paths_sourced=0
(return 0 2>/dev/null) && _smithy_paths_sourced=1
[ "$_smithy_paths_sourced" -eq 0 ] && set -uo pipefail

# Assigns rather than echoes: called on the PreToolUse hook path, where a
# command substitution would fork a subshell on every Bash tool call.
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

_smithy_trim() { # strip leading/trailing whitespace (builtin-only; keeps inner spaces)
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

_smithy_hash8() { # _smithy_hash8 <string> — 8 stable hex chars, whatever is installed
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
  # ONE git invocation for both answers — this runs on the PreToolUse hook path,
  # so a second rev-parse would cost ~7ms on every single Bash call.
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

_smithy_global_location() { # repo | external | ask  (only consulted by rule 5)
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

  # 1 — explicit env override
  if [ -n "${SMITHY_MEM_DIR:-}" ]; then
    SMITHY_MEM="$(_smithy_expand "$SMITHY_MEM_DIR" "$SMITHY_MAIN_ROOT")"
    SMITHY_MEM_SOURCE="env:SMITHY_MEM_DIR"
    return 0
  fi

  # 2 — in-repo pointer file (first non-comment, non-blank line)
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

  # 3 — global registry, keyed by absolute main-worktree root
  if [ -f "$SMITHY_REGISTRY" ]; then
    line="$(awk -F'\t' -v r="$SMITHY_MAIN_ROOT" '$1==r {print $2; exit}' "$SMITHY_REGISTRY" 2>/dev/null)"
    if [ -n "$line" ]; then
      SMITHY_MEM="$(_smithy_expand "$line" "$SMITHY_MAIN_ROOT")"
      SMITHY_MEM_SOURCE="registry:projects.tsv"
      return 0
    fi
  fi

  # 4 — an in-repo dir that already exists wins over any default (back-compat)
  if [ -d "$SMITHY_MAIN_ROOT/docs/smithy" ]; then
    SMITHY_MEM="$SMITHY_MAIN_ROOT/docs/smithy"
    SMITHY_MEM_SOURCE="existing:docs/smithy"
    return 0
  fi

  # 5 — nothing configured: where would a NEW memory dir go?
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

_smithy_lane_ok() { # a lane name must be safe to use as ONE path segment
  case "$1" in
    "" | .* | */* | *..*)  return 1 ;;
    *[!A-Za-z0-9._-]*)     return 1 ;;
  esac
  return 0
}

smithy_resolve_lane() { # sets SMITHY_LANE, SMITHY_LANE_SOURCE, SMITHY_STATE_DIR
  local raw="" src="none" line
  SMITHY_LANE_WARN=""

  # 1 — explicit env override (how a dispatcher pins one agent to one lane)
  if [ -n "${SMITHY_LANE:-}" ]; then
    raw="$SMITHY_LANE"; src="env:SMITHY_LANE"

  # 2 — marker at THIS worktree's root (not the main one: the whole point is
  #     that each linked worktree answers differently)
  elif [ -f "$SMITHY_ROOT/.smithy-lane" ]; then
    line="$(grep -v -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$SMITHY_ROOT/.smithy-lane" 2>/dev/null | head -1)"
    line="$(_smithy_trim "${line%$'\r'}")"
    if [ -n "$line" ]; then raw="$line"; src="marker:.smithy-lane"; fi
  fi

  if [ -n "$raw" ] && ! _smithy_lane_ok "$raw"; then
    SMITHY_LANE_WARN="ignoring invalid lane name '$raw' (from $src); using the shared state dir"
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

# `unset:ask` means the location is UNDECIDED — SMITHY_MEM is provisional and
# init-memory.sh refuses to create there until the user picks. Anything that
# only READS memory treats a missing dir as "not initialized", which is right.
SMITHY_GLOBAL_CONFIG="$SMITHY_HOME_DIR/config.json"
SMITHY_PROJECT_CONFIG="$SMITHY_MEM/config.json"
SMITHY_PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SMITHY_DEFAULTS="$SMITHY_PLUGIN_ROOT/defaults/config.json"
SMITHY_MODELS="$SMITHY_PLUGIN_ROOT/defaults/models.json"
SMITHY_GLOBAL_MODELS="$SMITHY_HOME_DIR/models.json"

[ "$_smithy_paths_sourced" -eq 1 ] && return 0

# ---------------------------------------------------------------- CLI --------
_registry_write() { # _registry_write <mem-dir|"">  — "" removes the entry
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
    echo "(recorded in $SMITHY_REGISTRY — nothing was written inside the repo)"
    ;;
  unset-mem)
    [ -f "$SMITHY_REGISTRY" ] || { echo "no registry at $SMITHY_REGISTRY"; exit 0; }
    _registry_write ""
    echo "unregistered: $SMITHY_MAIN_ROOT (memory dir left on disk)"
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
    # `&& printf` alone would make --dump exit 1 whenever there is no warning
    [ -n "${SMITHY_LANE_WARN:-}" ] && printf 'lane_warning=%s\n' "$SMITHY_LANE_WARN"
    true
    printf 'global_config=%s\n'  "$SMITHY_GLOBAL_CONFIG"
    printf 'project_config=%s\n' "$SMITHY_PROJECT_CONFIG"
    printf 'defaults=%s\n'       "$SMITHY_DEFAULTS"
    ;;
  -h|--help)
    # Print the whole leading comment block — a line range would silently
    # truncate every time this header grows.
    awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "${BASH_SOURCE[0]}"
    ;;
  "")
    echo "usage: paths.sh mem|mem-source|home|root|main-root|slug|registry|lane|lane-source|state-dir|set-mem <dir>|unset-mem|--dump" >&2
    exit 2 ;;
  *)
    echo "paths.sh: unknown command '$1' (try --help)" >&2; exit 2 ;;
esac
