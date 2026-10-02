#!/usr/bin/env bash
# route-guard.sh — makes every subagent dispatch use the model and effort
# that config sets. Code enforces it, not a prompt rule.
#
#   route-guard.sh hook           Hook mode (PreToolUse: runs before the
#                                 dispatch). Reads the hook JSON on stdin and
#                                 prints a hookSpecificOutput that rewrites the
#                                 dispatch to match config (or nothing if it
#                                 already matches). Always exits 0 (see below).
#   route-guard.sh check --agent <subagent_type> [--model M]
#                                [--prompt P | --prompt-file F]
#                                 Same decision, from the command line. Prints
#                                 the hook JSON, or "no change".
#   route-guard.sh table          Show the agent -> role -> model/effort map
#                                 this guard enforces right now.
#
# Why: references/dispatch.md §1 tells the controller to pass the routed model
# and put the routed effort banner first in the prompt. Prompt rules slip: the
# model parameter is left out (the subagent then uses the session's model), a
# cheaper tier is picked on a hunch, or the banner is forgotten. guard.sh made
# git safety a code rule; this does the same for routing. Config holds the
# policy (routing.<role>.model / .effort); this script enforces it.
#
# Fails OPEN (lets the dispatch through): guard.sh blocks when in doubt (the
# risk there is a destroyed repo); here the risk is only a slightly wrong
# model. So every error exits 0 with no output, and the dispatch runs as written.
#
# Claude Code only: no hooks run under Codex CLI, where dispatch.md §1 is only
# advice. See references/harness.md.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# NOT SMITHY_PATHS_FAST. guard.sh runs before every Bash call, so it must stay
# pure bash. This runs only when a subagent is dispatched, so starting one
# interpreter costs nothing next to the dispatch. In return we get path rule 5.
# Without it, a project that uses the external-memory default would quietly
# fall back to docs/smithy, and the guard would do nothing.
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"
export SMITHY_MEM SMITHY_DEFAULTS SMITHY_GLOBAL_CONFIG SMITHY_PROJECT_CONFIG \
       SMITHY_MODELS SMITHY_GLOBAL_MODELS

LIB="$SCRIPT_DIR/lib/route_guard.py"

case "${1:-}" in
  hook)
    # No python3 or no helper means "do not enforce", never "do not dispatch".
    # Read and drop stdin first, so the harness never sees a broken pipe.
    command -v python3 >/dev/null 2>&1 || { cat >/dev/null 2>&1; exit 0; }
    [ -f "$LIB" ] || { cat >/dev/null 2>&1; exit 0; }
    python3 "$LIB" hook || true
    exit 0
    ;;
  check)
    shift
    command -v python3 >/dev/null 2>&1 || { echo "route-guard.sh: python3 is required" >&2; exit 1; }
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
    [ -d "$SMITHY_MEM" ] || echo "NOTE: no memory folder — the hook does NOTHING in this project."
    ;;
  ""|-h|--help)
    sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    [ -n "${1:-}" ] || exit 2 ;;
  *)
    echo "route-guard.sh: unknown command '$1' (try --help)" >&2; exit 2 ;;
esac
