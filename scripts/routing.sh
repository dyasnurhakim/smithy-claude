#!/usr/bin/env bash
# routing.sh — find the model and effort for a smithy role (a kind of work,
# like review or testing).
#
# Usage:
#   routing.sh <role>     -> "model=sonnet effort=medium"
#   routing.sh --dump     -> the table in effect: one role per line, plus where each value came from
#   routing.sh --models   -> what this harness accepts as a model value
#   routing.sh --roles    -> the list of roles
#
# Which config wins (later beats earlier):
#   plugin defaults ──▶ $SMITHY_HOME/config.json ──▶ <memory-dir>/config.json
#                       (global, all projects)       (this project)
# paths.sh finds the memory folder, so it need NOT be inside the repo.
#
# A model value may be a tier (flagship/workhorse/fast), a family name
# (opus/sonnet/haiku/fable, sol/terra/luna), `inherit`, or any id that matches
# the harness's id_patterns in defaults/models.json. So a new model release
# needs no change here. A value from another harness's family is translated
# BY TIER (e.g. sol is flagship, so under Claude it becomes opus).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"
export SMITHY_DEFAULTS SMITHY_GLOBAL_CONFIG SMITHY_PROJECT_CONFIG SMITHY_MODELS SMITHY_GLOBAL_MODELS

LIB="$SCRIPT_DIR/lib/smithy_config.py"
[ -f "$SMITHY_DEFAULTS" ] || { echo "routing.sh: defaults not found at $SMITHY_DEFAULTS" >&2; exit 1; }
[ -f "$LIB" ] || { echo "routing.sh: helper not found at $LIB" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "routing.sh: python3 is required (it reads the config JSON) but is not on PATH" >&2; exit 1; }

cfg() { python3 "$LIB" "$@"; }

case "${1:-}" in
  --dump)
    echo "harness: $(cfg harness)"
    echo "memory:  $SMITHY_MEM  ($SMITHY_MEM_SOURCE)"
    printf "%-16s %-14s %-8s %s\n" "ROLE" "MODEL" "EFFORT" "SOURCE"
    cfg routing | while IFS=$'\t' read -r role model effort source; do
      printf "%-16s %-14s %-8s %s\n" "$role" "$model" "$effort" "$source"
    done
    echo
    cfg layers | while IFS=$'\t' read -r layer path exists; do
      printf "config layer %-9s %-4s %s\n" "$layer" "$exists" "$path"
    done
    ;;
  --models)
    echo "harness: $(cfg harness)"
    printf "%-24s %-10s %s\n" "VALUE" "TIER" "KIND"
    cfg models | while IFS=$'\t' read -r name tier kind; do
      printf "%-24s %-10s %s\n" "$name" "$tier" "$kind"
    done
    echo "efforts: $(cfg efforts)"
    ;;
  --roles)
    cfg roles ;;
  "")
    echo "usage: routing.sh <role>|--dump|--models|--roles  (roles: $(cfg roles))" >&2; exit 2 ;;
  -*)
    echo "routing.sh: unknown flag '$1' (try --dump)" >&2; exit 2 ;;
  *)
    row="$(cfg routing "$1")" || exit 2
    IFS=$'\t' read -r _role model effort _source <<<"$row"
    echo "model=$model effort=$effort"
    ;;
esac
