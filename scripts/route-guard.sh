#!/usr/bin/env bash
# route-guard.sh — deterministic model/effort routing at subagent dispatch.
#
#   route-guard.sh hook           PreToolUse hook mode: reads the hook JSON on
#                                 stdin, prints a hookSpecificOutput that
#                                 rewrites the dispatch to match config (or
#                                 prints nothing when it already does). Always
#                                 exits 0 — see "fail-open" below.
#   route-guard.sh check --agent <subagent_type> [--model M]
#                                [--prompt P | --prompt-file F]
#                                 Same decision, from the command line. Prints
#                                 the hook JSON, or "no change".
#   route-guard.sh table          Show the agent -> role -> model/effort map
#                                 this guard will enforce right now.
#
# Why this exists: references/dispatch.md §1 tells the controller to pass the
# routed model and prepend the routed effort banner. That is a PROMPT rule, and
# prompt rules drift — the model omits the model parameter (the subagent then
# inherits the session model), downgrades a tier by intuition, or forgets the
# banner. guard.sh made git safety deterministic; this does the same for
# routing. Policy lives in config (routing.<role>.model / .effort), enforcement
# lives here, and neither depends on the controller remembering.
#
# Fail-open: unlike guard.sh (which blocks on doubt, because the risk is a
# destroyed repo), the risk here is a slightly-wrong model. A guard that cannot
# decide must never be the reason a dispatch dies, so every error path exits 0
# with no output and the dispatch proceeds as written.
#
# Claude Code only — no hooks run under Codex CLI, where dispatch.md §1 stays
# advisory. See references/harness.md.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# NOT SMITHY_PATHS_FAST: unlike guard.sh — which runs before every Bash call and
# so must stay pure bash — this runs only when a subagent is dispatched. One
# interpreter spawn per dispatch is nothing next to the dispatch itself, and it
# buys resolution rule 5, without which a project using the external-memory
# default would silently fall back to docs/smithy and leave the guard inactive.
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"
export SMITHY_MEM SMITHY_DEFAULTS SMITHY_GLOBAL_CONFIG SMITHY_PROJECT_CONFIG \
       SMITHY_MODELS SMITHY_GLOBAL_MODELS

LIB="$SCRIPT_DIR/lib/route_guard.py"

case "${1:-}" in
  hook)
    # Missing python3 or a missing helper means "no enforcement", not "no
    # dispatch". Swallow stdin first so the harness never sees a broken pipe.
    command -v python3 >/dev/null 2>&1 || { cat >/dev/null 2>&1; exit 0; }
    [ -f "$LIB" ] || { cat >/dev/null 2>&1; exit 0; }
    python3 "$LIB" hook || true
    exit 0
    ;;
  check)
    shift
    command -v python3 >/dev/null 2>&1 || { echo "route-guard.sh: python3 required" >&2; exit 1; }
    exec python3 "$LIB" check "$@"
    ;;
  table)
    printf "%-12s %-16s %-14s %s\n" "AGENT" "ROLE" "MODEL" "EFFORT"
    for pair in forger:implementation jigsmith:implementation inspector:review \
                annealer:debugging temperer:testing; do
      agent="${pair%%:*}"; role="${pair##*:}"
      row="$(bash "$SCRIPT_DIR/routing.sh" "$role" 2>/dev/null)" || row=""
      model="${row#model=}"; model="${model%% *}"
      effort="${row##*effort=}"
      printf "%-12s %-16s %-14s %s\n" "$agent" "$role" "${model:-?}" "${effort:-?}"
    done
    echo
    echo "memory: $SMITHY_MEM ($SMITHY_MEM_SOURCE)"
    [ -d "$SMITHY_MEM" ] || echo "NOTE: memory dir absent — the hook is INACTIVE in this project."
    ;;
  ""|-h|--help)
    sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    [ -n "${1:-}" ] || exit 2 ;;
  *)
    echo "route-guard.sh: unknown command '$1' (try --help)" >&2; exit 2 ;;
esac
