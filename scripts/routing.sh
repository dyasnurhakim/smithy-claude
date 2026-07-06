#!/usr/bin/env bash
# routing.sh — resolve model/effort for a smithy pipeline role.
#
# Usage:
#   routing.sh <role>     -> "model=sonnet effort=medium"
#   routing.sh --dump     -> effective table, one role per line, with source column
#
# Precedence: <project>/docs/smithy/config.json overrides <plugin>/defaults/config.json
# per role key. Invalid values warn to stderr and fall back to defaults.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULTS="$SCRIPT_DIR/../defaults/config.json"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
PROJECT_CONFIG="$PROJECT_ROOT/docs/smithy/config.json"

VALID_MODELS="opus sonnet haiku inherit"
VALID_EFFORTS="low medium high max"
ROLES="research planning implementation review debugging testing mechanical"

[ -f "$DEFAULTS" ] || { echo "routing.sh: defaults not found at $DEFAULTS" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "routing.sh: python3 is required (used to parse config JSON) but not on PATH" >&2; exit 1; }

# Validate the project config ONCE: a malformed file warns loudly (single line)
# and is then ignored — silent fallback would hide that overrides stopped applying.
if [ -f "$PROJECT_CONFIG" ] && ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$PROJECT_CONFIG" 2>/dev/null; then
  echo "routing.sh: WARNING: $PROJECT_CONFIG is not valid JSON — ALL project overrides ignored; using defaults" >&2
  PROJECT_CONFIG=""
fi

json_get() { # json_get <file> <role> <field> — missing keys are silent (expected for sparse configs)
  python3 - "$1" "$2" "$3" <<'PY'
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
    print(cfg.get("routing", {}).get(sys.argv[2], {}).get(sys.argv[3], ""))
except Exception:
    print("")
PY
}

valid_in() { # valid_in <value> <space-separated-set>
  case " $2 " in *" $1 "*) return 0 ;; *) return 1 ;; esac
}

resolve() { # resolve <role> -> prints "model effort source"
  local role="$1" model effort source="default"
  model="$(json_get "$DEFAULTS" "$role" model)"
  effort="$(json_get "$DEFAULTS" "$role" effort)"
  if [ -f "$PROJECT_CONFIG" ]; then
    local pm pe
    pm="$(json_get "$PROJECT_CONFIG" "$role" model)"
    pe="$(json_get "$PROJECT_CONFIG" "$role" effort)"
    if [ -n "$pm" ]; then
      if valid_in "$pm" "$VALID_MODELS"; then model="$pm"; source="project"
      else echo "routing.sh: invalid model '$pm' for role '$role' in project config; using default" >&2; fi
    fi
    if [ -n "$pe" ]; then
      if valid_in "$pe" "$VALID_EFFORTS"; then effort="$pe"; source="project"
      else echo "routing.sh: invalid effort '$pe' for role '$role' in project config; using default" >&2; fi
    fi
  fi
  echo "$model $effort $source"
}

case "${1:-}" in
  --dump)
    printf "%-16s %-8s %-8s %s\n" "ROLE" "MODEL" "EFFORT" "SOURCE"
    for role in $ROLES; do
      read -r m e s <<<"$(resolve "$role")"
      printf "%-16s %-8s %-8s %s\n" "$role" "$m" "$e" "$s"
    done
    ;;
  "")
    echo "usage: routing.sh <role>|--dump  (roles: $ROLES)" >&2; exit 2 ;;
  *)
    role="$1"
    valid_in "$role" "$ROLES" || { echo "routing.sh: unknown role '$role' (roles: $ROLES)" >&2; exit 2; }
    read -r m e _ <<<"$(resolve "$role")"
    echo "model=$m effort=$e"
    ;;
esac
