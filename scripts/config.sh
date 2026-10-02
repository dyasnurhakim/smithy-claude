#!/usr/bin/env bash
# config.sh — read and write smithy config. Config comes in three layers.
#
#   config.sh get <dotted.key>                 the value in effect (exit 1 if not set)
#   config.sh source <dotted.key>              which layer gave that value
#   config.sh layers                           the three layer files, and which exist
#   config.sh set global  <dotted.key> <value> write the GLOBAL layer (all projects)
#   config.sh set project <dotted.key> <value> write THIS project's layer
#   config.sh show global|project              print that layer's file as it is
#   config.sh memory-location [repo|external|ask]
#                                              read or set the global default for
#                                              where NEW projects keep memory
#
# Layers — a higher layer wins over the ones below it:
#   project   <memory-dir>/config.json           this project only         (wins)
#   global    $SMITHY_HOME/config.json           every project
#   defaults  <plugin>/defaults/config.json      never edited per project  (base)
#
# A value is read as JSON when it parses, else as a plain string:
#   config.sh set project gates.pause_between_phases false
#   config.sh set global  routing.review.model flagship
#   config.sh set project testing.skip '["proof","hone"]'
#
# Writes stay small: setting a key to the exact value the layer below already
# gives REMOVES the key instead of copying it.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"
export SMITHY_DEFAULTS SMITHY_GLOBAL_CONFIG SMITHY_PROJECT_CONFIG SMITHY_MODELS SMITHY_GLOBAL_MODELS

LIB="$SCRIPT_DIR/lib/smithy_config.py"
command -v python3 >/dev/null 2>&1 || { echo "config.sh: python3 is required but not on PATH" >&2; exit 1; }
[ -f "$LIB" ] || { echo "config.sh: helper not found at $LIB" >&2; exit 1; }

cfg() { python3 "$LIB" "$@"; }

case "${1:-}" in
  get)
    [ $# -eq 2 ] || { echo "usage: config.sh get <dotted.key>" >&2; exit 2; }
    cfg get "$2" ;;
  source)
    [ $# -eq 2 ] || { echo "usage: config.sh source <dotted.key>" >&2; exit 2; }
    cfg get-source "$2" ;;
  layers)
    printf "%-9s %-4s %s\n" "LAYER" "HAS" "PATH"
    cfg layers | while IFS=$'\t' read -r layer path exists; do
      printf "%-9s %-4s %s\n" "$layer" "$exists" "$path"
    done ;;
  set)
    [ $# -eq 4 ] || { echo "usage: config.sh set global|project <dotted.key> <value>" >&2; exit 2; }
    case "$2" in
      global|project) ;;
      *) echo "config.sh: layer must be 'global' or 'project' (got '$2')" >&2; exit 2 ;;
    esac
    if [ "$2" = "project" ] && [ ! -d "$SMITHY_MEM" ]; then
      echo "config.sh: no project memory at $SMITHY_MEM ($SMITHY_MEM_SOURCE)." >&2
      echo "           Run init-memory.sh first — it decides WHERE memory lives." >&2
      exit 1
    fi
    cfg set "$2" "$3" "$4" ;;
  show)
    case "${2:-}" in
      global)  f="$SMITHY_GLOBAL_CONFIG" ;;
      project) f="$SMITHY_PROJECT_CONFIG" ;;
      *) echo "usage: config.sh show global|project" >&2; exit 2 ;;
    esac
    if [ -f "$f" ]; then echo "# $f"; cat "$f"; else echo "# $f (does not exist — no overrides)"; fi ;;
  memory-location)
    if [ $# -eq 1 ]; then
      loc="$(cfg get memory.location 2>/dev/null)" || loc=""
      echo "${loc:-ask}   (global default for NEW projects; source: $SMITHY_GLOBAL_CONFIG)"
      echo "this project: $SMITHY_MEM  ($SMITHY_MEM_SOURCE)"
    else
      case "$2" in
        repo|external|ask) cfg set global memory.location "$2" ;;
        *) echo "config.sh: memory-location must be repo|external|ask" >&2; exit 2 ;;
      esac
    fi ;;
  ""|-h|--help)
    sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    [ -n "${1:-}" ] || exit 2 ;;
  *)
    echo "config.sh: unknown command '$1' (try --help)" >&2; exit 2 ;;
esac
