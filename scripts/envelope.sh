#!/usr/bin/env bash
# envelope.sh — read and check the smithy envelope: a small YAML header at the
# top of a brief or report.
#
#   envelope.sh get <file> <field>      -> one value (empty if the field is missing)
#   envelope.sh list <file> <field>     -> list items, one per line
#   envelope.sh validate <file>         -> exit 0 = ok, 1 = invalid (reasons on stderr)
#
#   ---smithy          <- must be line 1
#   kind: brief
#   key_facts:
#     - ...
#   ---                <- the envelope ends at the next `---`
#
# Flat fields only (single values + one-level lists), so no YAML library is needed.
set -euo pipefail

extract() { # extract <file> -> the lines inside the envelope
  awk 'NR==1 && $0!="---smithy" {exit 1} NR==1 {next} /^---$/ {exit} {print}' "$1"
}

case "${1:-}" in
  get)
    [ $# -eq 3 ] || { echo "usage: envelope.sh get <file> <field>" >&2; exit 2; }
    extract "$2" | sed -n "s/^$3:[[:space:]]*//p" | head -1 | sed 's/^"\(.*\)"$/\1/'
    ;;
  list)
    [ $# -eq 3 ] || { echo "usage: envelope.sh list <file> <field>" >&2; exit 2; }
    extract "$2" | awk -v f="$3" '
      $0 ~ "^"f":" { if ($0 ~ /\[\]/) exit; inlist=1; next }
      inlist && /^[[:space:]]*-[[:space:]]/ { sub(/^[[:space:]]*-[[:space:]]*/,""); gsub(/^"|"$/,""); print; next }
      inlist { exit }'
    ;;
  validate)
    [ $# -eq 2 ] || { echo "usage: envelope.sh validate <file>" >&2; exit 2; }
    f="$2"; ok=0
    [ -f "$f" ] || { echo "envelope: file not found: $f" >&2; exit 1; }
    if ! head -1 "$f" | grep -qx -- '---smithy'; then
      echo "envelope: line 1 is not '---smithy'" >&2; exit 1
    fi
    env_body="$(extract "$f")" || { echo "envelope: no closing '---'" >&2; exit 1; }
    kind="$(echo "$env_body" | sed -n 's/^kind:[[:space:]]*//p' | head -1)"
    # Briefs need less: artifacts and next_action are optional (key_facts and
    # concerns are still required).
    if [ "$kind" = "brief" ]; then
      req_fields="schema kind job unit"; req_lists="key_facts concerns"
    else
      req_fields="schema kind job unit next_action"; req_lists="artifacts key_facts concerns"
    fi
    for req in $req_fields; do
      echo "$env_body" | grep -q "^$req:" || { echo "envelope: missing required field '$req'" >&2; ok=1; }
    done
    for lst in $req_lists; do
      echo "$env_body" | grep -q "^$lst:" || { echo "envelope: missing required list '$lst'" >&2; ok=1; }
    done
    case " brief impl-report review-verdict rca test-report guild-verdict forge-report persona " in
      *" $kind "*) ;;
      *) echo "envelope: unknown kind '$kind'" >&2; ok=1 ;;
    esac
    exit $ok
    ;;
  *)
    echo "usage: envelope.sh get|list|validate ..." >&2; exit 2 ;;
esac
