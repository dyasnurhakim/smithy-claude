#!/usr/bin/env bash
# smithy SessionStart hook — two jobs, both read-only and fail-silent:
#   1. Inject the using-smithy routing skill so every session knows WHEN to
#      reach for which smithy skill (adoption discipline; superpowers pattern).
#   2. If the project has smithy memory, surface the state head so the
#      session knows work exists.
set -u

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
USING="$PLUGIN_ROOT/skills/using-smithy/SKILL.md"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
STATE="$ROOT/docs/smithy/STATE.md"

{
  if [ -f "$USING" ]; then
    echo "<smithy-routing>"
    echo "Smithy is installed. The following is the full using-smithy skill — your router for when to use which smithy skill:"
    echo
    # strip frontmatter (everything between the first two '---' lines)
    awk 'BEGIN{fm=0} /^---$/{fm++; next} fm!=1{print}' "$USING"
    echo "</smithy-routing>"
  fi

  if [ -f "$STATE" ]; then
    echo "[smithy] Project memory found (docs/smithy/):"
    head -n 40 "$STATE"
    echo "[smithy] Resume with /smithy — it recomputes position from docs/smithy/ledger.md, not recollection."
  fi
} 2>/dev/null

exit 0
