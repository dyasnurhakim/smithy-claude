#!/usr/bin/env bash
set -u
# Self-contained route-guard.sh test matrix. Run: bash tests/route-guard-matrix.sh
#
# Covers the two halves of the guard: the DECISION (which role, which model,
# which banner) and the HOOK CONTRACT (what lands on stdout, and the fail-open
# promise that a dispatch never dies because the guard did).
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
cd "$D" && git init -q -b main && mkdir -p docs/smithy
# isolate the GLOBAL layer + registry so a real ~/.smithy never leaks in
export SMITHY_HOME="$D/smithy-home"; mkdir -p "$SMITHY_HOME"
# docs/smithy exists -> resolution rule 4 makes this a smithy-managed project
export SMITHY_MEM_DIR="$D/docs/smithy"
GC="$SMITHY_HOME/config.json"
PC="docs/smithy/config.json"
fails=0

RG="bash $S/route-guard.sh"

B_LOW="Effort: LOW. Keep it short and mechanical. Do only what the brief says; do not explore beyond it."
B_MED="Effort: MEDIUM. Think through the edge cases before you act."
B_HIGH="Effort: HIGH. Think hard. List the possible explanations or options before you pick one."
B_MAX="Effort: MAX. Ultrathink. Try every option. Before you decide, make the strongest case for the opposite answer."

g() { # g <desc> <expect-substr> <cmd...> — assert stdout CONTAINS
  local desc="$1" want="$2"; shift 2
  if "$@" 2>/dev/null | grep -qF -- "$want"; then printf 'PASS  %s\n' "$desc"
  else printf 'FAIL! %-50s no match for %s\n' "$desc" "$want"; fails=$((fails+1)); fi
}
ng() { # ng <desc> <forbidden-substr> <cmd...> — assert stdout does NOT contain
  local desc="$1" want="$2"; shift 2
  if "$@" 2>/dev/null | grep -qF -- "$want"; then
    printf 'FAIL! %-50s unexpected %s\n' "$desc" "$want"; fails=$((fails+1))
  else printf 'PASS  %s\n' "$desc"; fi
}
empty() { # empty <desc> <cmd...> — assert stdout is EMPTY and exit code is 0
  local desc="$1"; shift
  local out rc
  out="$("$@" 2>/dev/null)"; rc=$?
  if [ -z "$out" ] && [ $rc -eq 0 ]; then printf 'PASS  %s\n' "$desc"
  else printf 'FAIL! %-50s rc=%s out=%s\n' "$desc" "$rc" "$out"; fails=$((fails+1)); fi
}
reset_global() { printf '{"smithy_config_version":1}' > "$GC"; }
reset_global
printf '{"smithy_config_version":1}' > $PC

echo "--- defaults: model injection ---"
g "missing model injected (inspector->review=opus)" '"model": "opus"' \
  $RG check --agent smithy:inspector --prompt "$B_HIGH"
g "wrong model corrected (haiku->opus)"       '"model": "opus"' \
  $RG check --agent smithy:inspector --model haiku --prompt "$B_HIGH"
g "correction is reported"                    "model haiku -> opus" \
  $RG check --agent smithy:inspector --model haiku --prompt "$B_HIGH"
g "forger routes implementation (sonnet)"     '"model": "sonnet"' \
  $RG check --agent smithy:forger --prompt "$B_MED"
g "jigsmith routes implementation (sonnet)"   '"model": "sonnet"' \
  $RG check --agent smithy:jigsmith --prompt "$B_MED"
g "annealer routes debugging (opus)"          '"model": "opus"' \
  $RG check --agent smithy:annealer --prompt "$B_HIGH"
g "temperer routes testing (sonnet)"          '"model": "sonnet"' \
  $RG check --agent smithy:temperer --prompt "$B_MED"
g "bare agent name also routed"               '"model": "opus"' \
  $RG check --agent inspector --prompt "$B_HIGH"

echo "--- effort banner ---"
g "missing banner prepended"                  "Effort: HIGH." \
  $RG check --agent smithy:inspector --model opus --prompt "Job auth, task 3."
g "wrong banner replaced"                     "Effort: HIGH." \
  $RG check --agent smithy:inspector --model opus --prompt "$B_LOW

Job auth."
ng "wrong banner actually removed"            "Effort: LOW." \
  $RG check --agent smithy:inspector --model opus --prompt "$B_LOW

Job auth."
g "stale banner mid-prompt stripped"          "Effort: HIGH." \
  $RG check --agent smithy:inspector --model opus --prompt "Job auth.
$B_LOW
more"
ng "stale mid-prompt banner removed"          "Effort: LOW." \
  $RG check --agent smithy:inspector --model opus --prompt "Job auth.
$B_LOW
more"
g "prompt body preserved"                     "Job auth, task 3." \
  $RG check --agent smithy:inspector --model opus --prompt "Job auth, task 3."

echo "--- already-correct dispatch is untouched ---"
g "correct model+banner = no change"          "no change" \
  $RG check --agent smithy:inspector --model opus --prompt "$B_HIGH

Job auth."

echo "--- scope: non-smithy dispatches ---"
g "general-purpose untouched"                 "no change" \
  $RG check --agent general-purpose --model haiku --prompt "do a thing"
g "another plugin's same-named agent untouched" "no change" \
  $RG check --agent other:forger --model haiku --prompt "do a thing"
g "unknown smithy agent untouched"            "no change" \
  $RG check --agent smithy:nosuchagent --model haiku --prompt "do a thing"

echo "--- role override marker ---"
g "smithy-role: mechanical -> haiku"          '"model": "haiku"' \
  $RG check --agent smithy:forger --prompt "smithy-role: mechanical"
g "override also drives the banner (low)"     "Effort: LOW." \
  $RG check --agent smithy:forger --prompt "smithy-role: mechanical"
g "bogus override falls back to agent map"    '"model": "sonnet"' \
  $RG check --agent smithy:forger --prompt "smithy-role: nonsense"

echo "--- config layers drive the enforcement ---"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"fable","effort":"max"}}}' > $PC
g "project config: review->fable"             '"model": "fable"' \
  $RG check --agent smithy:inspector --model opus --prompt "$B_HIGH"
g "project config: review effort->max banner" "Effort: MAX." \
  $RG check --agent smithy:inspector --model opus --prompt "$B_HIGH"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"flagship","effort":"xhigh"}}}' > $PC
g "tier value expands to a real model"        '"model": "opus"' \
  $RG check --agent smithy:inspector --prompt "$B_HIGH"
g "xhigh banner enforced"                     "Effort: XHIGH." \
  $RG check --agent smithy:inspector --prompt "$B_HIGH"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"workhorse"}}}' > "$GC"
printf '{"smithy_config_version":1}' > $PC
g "global layer applies when project silent"  '"model": "sonnet"' \
  $RG check --agent smithy:inspector --prompt "$B_HIGH"
reset_global

echo "--- values that must NOT be injected ---"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"inherit"}}}' > $PC
ng "inherit drops the model key"              '"model"' \
  $RG check --agent smithy:inspector --model haiku --prompt "$B_HIGH"
g "inherit is reported"                       "routes to inherit" \
  $RG check --agent smithy:inspector --model haiku --prompt "$B_HIGH"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"claude-opus-9-9"}}}' > $PC
ng "raw future id not injected"               '"model": "claude-opus-9-9"' \
  $RG check --agent smithy:inspector --model opus --prompt "$B_HIGH"
g "raw future id warns instead"               "cannot accept as a dispatch value" \
  $RG check --agent smithy:inspector --model opus --prompt "$B_HIGH"
printf '{"smithy_config_version":1,"harness":"codex","routing":{}}' > $PC
ng "codex-configured harness: no model injected" '"model": "sol"' \
  $RG check --agent smithy:inspector --model opus --prompt "$B_HIGH"
g "codex-configured harness warns"            "plugin hooks only run under claude" \
  $RG check --agent smithy:inspector --model opus --prompt "$B_HIGH"
g "banner still enforced under wrong harness" "Effort: HIGH." \
  $RG check --agent smithy:inspector --model opus --prompt "Job auth."
printf '{"smithy_config_version":1}' > $PC

echo "--- hook mode: stdin contract ---"
g "hook emits hookSpecificOutput"             '"hookEventName": "PreToolUse"' \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"smithy:inspector\",\"prompt\":\"go\"}}' | $RG hook"
ng "hook emits no permissionDecision"         "permissionDecision" \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"smithy:inspector\",\"prompt\":\"go\"}}' | $RG hook"
empty "correct dispatch emits nothing" \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"smithy:inspector\",\"model\":\"opus\",\"prompt\":\"$B_HIGH\"}}' | $RG hook"
empty "Bash-shaped payload emits nothing" \
  bash -c "printf '%s' '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}' | $RG hook"
empty "malformed JSON fails open" \
  bash -c "printf '%s' 'not json at all' | $RG hook"
empty "empty stdin fails open" \
  bash -c "printf '' | $RG hook"
empty "null tool_input fails open" \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":null}' | $RG hook"
g "unknown tool_input keys ride along"        '"isolation": "worktree"' \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"smithy:inspector\",\"prompt\":\"go\",\"isolation\":\"worktree\"}}' | $RG hook"

echo "--- outside a smithy-managed project (no memory folder) ---"
# Dispatching a smithy:* agent IS using smithy, so routing applies anywhere
# (config = defaults + global). Bare names stay unchecked there: they may be
# the project's OWN agents that merely share a name.
g "smithy:* agent is routed with no memory dir" '"updatedInput"' \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"smithy:inspector\",\"prompt\":\"go\"}}' | SMITHY_MEM_DIR=$D/nonexistent-mem $RG hook"
empty "bare-name agent is left alone with no memory dir" \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"inspector\",\"prompt\":\"go\"}}' | SMITHY_MEM_DIR=$D/nonexistent-mem $RG hook"
empty "other agents are left alone with no memory dir" \
  bash -c "printf '%s' '{\"tool_name\":\"Agent\",\"tool_input\":{\"subagent_type\":\"general-purpose\",\"prompt\":\"go\"}}' | SMITHY_MEM_DIR=$D/nonexistent-mem $RG hook"

echo
if [ $fails -eq 0 ]; then echo "route-guard matrix: ALL PASS"; else echo "route-guard matrix: $fails FAILURE(S)"; fi
exit $fails
