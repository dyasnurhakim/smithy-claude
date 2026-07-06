#!/usr/bin/env bash
# envelope.sh — read/validate the smithy YAML envelope at the top of a file.
#
#   envelope.sh get <file> <field>      -> scalar value (empty if absent)
#   envelope.sh list <file> <field>     -> list items, one per line
#   envelope.sh validate <file>         -> exit 0 ok / 1 invalid (+ reasons to stderr)
#
# Envelope = lines between a first-line `---smithy` marker and the next `---`.
# Flat schema only (scalars + one-level lists) — parsed without a YAML lib.
set -euo pipefail

extract() { # extract <file> -> envelope body lines
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
    for req in schema kind job unit next_action; do
      echo "$env_body" | grep -q "^$req:" || { echo "envelope: missing required field '$req'" >&2; ok=1; }
    done
    for lst in artifacts key_facts concerns; do
      echo "$env_body" | grep -q "^$lst:" || { echo "envelope: missing required list '$lst'" >&2; ok=1; }
    done
    kind="$(echo "$env_body" | sed -n 's/^kind:[[:space:]]*//p' | head -1)"
    case " brief impl-report review-verdict rca test-report guild-verdict persona " in
      *" $kind "*) ;;
      *) echo "envelope: unknown kind '$kind'" >&2; ok=1 ;;
    esac
    exit $ok
    ;;
  *)
    echo "usage: envelope.sh get|list|validate ..." >&2; exit 2 ;;
esac
