#!/usr/bin/env bash
set -u
# Self-contained routing.sh test matrix. Run: bash tests/routing-matrix.sh
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
cd "$D" && git init -q -b main && mkdir -p docs/smithy
# isolate the GLOBAL layer + registry so a real ~/.smithy never leaks in
export SMITHY_HOME="$D/smithy-home"; mkdir -p "$SMITHY_HOME"
GC="$SMITHY_HOME/config.json"
PC="docs/smithy/config.json"
fails=0
t() { # t <desc> <expect-substr> <cmd...>
  local desc="$1" want="$2"; shift 2
  got="$("$@" 2>/dev/null)"
  case "$got" in *"$want"*) printf 'PASS  %-45s %s\n' "$desc" "$got" ;;
  *) printf 'FAIL! %-45s want~%s got=%s\n' "$desc" "$want" "$got"; fails=$((fails+1)) ;; esac
}
g() { # g <desc> <expect-substr> <cmd...>  — grep-style: assert output CONTAINS
  local desc="$1" want="$2"; shift 2
  if "$@" 2>/dev/null | grep -q -- "$want"; then printf 'PASS  %s\n' "$desc"
  else printf 'FAIL! %-45s no match for %s\n' "$desc" "$want"; fails=$((fails+1)); fi
}
e() { # e <desc> <expect-substr> <cmd...> — assert STDERR contains (warnings)
  local desc="$1" want="$2"; shift 2
  if "$@" 2>&1 1>/dev/null | grep -q -- "$want"; then printf 'PASS  %s\n' "$desc"
  else printf 'FAIL! %-45s stderr lacks %s\n' "$desc" "$want"; fails=$((fails+1)); fi
}
ng() { # ng <desc> <forbidden-substr> <cmd...> — assert output does NOT contain
  local desc="$1" want="$2"; shift 2
  if "$@" 2>/dev/null | grep -q -- "$want"; then
    printf 'FAIL! %-45s unexpected %s\n' "$desc" "$want"; fails=$((fails+1))
  else printf 'PASS  %s\n' "$desc"; fi
}
reset_global() { printf '{"smithy_config_version":1}' > "$GC"; }
reset_global

echo "--- defaults + tier expansion ---"
printf '{"smithy_config_version":1,"routing":{}}' > $PC
t "claude default: review=opus"        "model=opus"   bash $S/routing.sh review
t "claude default: testing=sonnet"     "model=sonnet" bash $S/routing.sh testing
t "claude default: mechanical=haiku"   "model=haiku"  bash $S/routing.sh mechanical
g "tier defaults marked (tier)"        "defaults(tier)" bash $S/routing.sh --dump

echo "--- cross-family translation ---"
printf '{"smithy_config_version":1,"harness":"codex","routing":{}}' > $PC
t "codex: flagship->sol"               "model=sol"    bash $S/routing.sh review
t "codex: workhorse->terra"            "model=terra"  bash $S/routing.sh testing
t "codex: fast->luna"                  "model=luna"   bash $S/routing.sh mechanical
printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"sol","effort":"max"}}}' > $PC
t "codex: native sol accepted"         "model=sol effort=max" bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"terra","effort":"high"}}}' > $PC
t "claude: terra translates->sonnet"   "model=sonnet" bash $S/routing.sh review
printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"opus"}}}' > $PC
g "explicit cross-family = (translated)" "project(translated)" bash $S/routing.sh --dump
printf '{"smithy_config_version":1,"harness":"codex","routing":{"planning":{"model":"fable","effort":"max"}}}' > $PC
t "codex: fable->sol (flagship tier)"  "model=sol"    bash $S/routing.sh planning
printf '{"smithy_config_version":1,"harness":"gemini","routing":{}}' > $PC
t "unknown harness falls back claude"  "model=opus"   bash $S/routing.sh review

echo "--- explicit + FUTURE model ids (no code change needed) ---"
printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"gpt-5.5","effort":"high"}}}' > $PC
t "codex: older gpt-5.5 passes through" "model=gpt-5.5" bash $S/routing.sh review
printf '{"smithy_config_version":1,"harness":"codex","routing":{"testing":{"model":"gpt-5.4-codex","effort":"low"}}}' > $PC
t "codex: gpt-5.4-codex passes through" "model=gpt-5.4-codex" bash $S/routing.sh testing
printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"gpt-7-omega","effort":"max"}}}' > $PC
t "codex: UNRELEASED gpt-7 passes"      "model=gpt-7-omega" bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"claude-opus-6-20270101","effort":"max"}}}' > $PC
t "claude: UNRELEASED claude-opus-6"    "model=claude-opus-6-20270101" bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"sonnet-9","effort":"high"}}}' > $PC
t "claude: UNRELEASED sonnet-9"         "model=sonnet-9" bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"flagship","effort":"high"}}}' > $PC
t "tier name usable as a config value"  "model=opus"   bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"gpt-5.5","effort":"high"}}}' > $PC
t "claude: gpt-5.5 foreign -> default"  "model=opus"   bash $S/routing.sh review
printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"totally-fake","effort":"high"}}}' > $PC
t "invalid model name rejected at entry" "model=sol"   bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"opus","effort":"turbo"}}}' > $PC
t "invalid effort falls back to default" "effort=high" bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"inherit","effort":"high"}}}' > $PC
t "inherit passes through untouched"     "model=inherit" bash $S/routing.sh review

echo "--- user-extended registry (\$SMITHY_HOME/models.json) ---"
cat > "$SMITHY_HOME/models.json" <<'J'
{"harnesses":{"gemini":{"models":{"ultra":"flagship","pro":"workhorse","flash":"fast"},
 "tier_default":{"flagship":"ultra","workhorse":"pro","fast":"flash"},
 "id_patterns":["gemini-*"]}}}
J
printf '{"smithy_config_version":1,"harness":"gemini","routing":{}}' > $PC
t "added harness: flagship->ultra"     "model=ultra"  bash $S/routing.sh review
t "added harness: fast->flash"         "model=flash"  bash $S/routing.sh mechanical
printf '{"smithy_config_version":1,"harness":"gemini","routing":{"review":{"model":"gemini-9-pro"}}}' > $PC
t "added harness: pattern passthrough" "model=gemini-9-pro" bash $S/routing.sh review
rm -f "$SMITHY_HOME/models.json"

echo "--- THREE config layers: defaults < global < project ---"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"fable","effort":"max"},"testing":{"model":"opus"}}}' > "$GC"
printf '{"smithy_config_version":1,"routing":{}}' > $PC
t "global layer applies"               "model=fable effort=max" bash $S/routing.sh review
g "global rows marked 'global'"        "global" bash $S/routing.sh --dump
printf '{"smithy_config_version":1,"routing":{"review":{"model":"haiku","effort":"low"}}}' > $PC
t "project beats global"               "model=haiku effort=low" bash $S/routing.sh review
t "global still applies elsewhere"     "model=opus"   bash $S/routing.sh testing
t "defaults still apply elsewhere"     "model=sonnet" bash $S/routing.sh research
printf '{"smithy_config_version":1,"routing":{"review":{"effort":"low"}}}' > $PC
t "per-FIELD merge: model global, effort project" "model=fable effort=low" bash $S/routing.sh review
reset_global

echo "--- malformed configs warn and are ignored, never silently ---"
printf '{"smithy_config_version":1,"routing":{' > $PC
t "malformed project config -> defaults" "model=opus" bash $S/routing.sh review
e "malformed project config warns loudly" "not valid JSON" bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{}}' > $PC
printf 'nope{' > "$GC"
t "malformed global config -> defaults"  "model=opus" bash $S/routing.sh review
e "malformed global config warns loudly" "not valid JSON" bash $S/routing.sh review
reset_global
printf '{"smithy_config_version":1,"harness":"nope","routing":{}}' > $PC
e "unknown harness warns loudly"         "unknown harness" bash $S/routing.sh review
printf '{"smithy_config_version":1,"routing":{"review":{"model":"totally-fake"}}}' > $PC
e "invalid model warns loudly"           "invalid model" bash $S/routing.sh review

echo "--- memory dir OUTSIDE the repo feeds the project layer ---"
EXT="$D/external-mem"; mkdir -p "$EXT"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"haiku","effort":"low"}}}' > "$EXT/config.json"
printf '{"smithy_config_version":1,"routing":{"review":{"model":"fable"}}}' > $PC
bash $S/paths.sh set-mem "$EXT" >/dev/null
t "registry-resolved config wins"      "model=haiku effort=low" bash $S/routing.sh review
g "--dump reports the resolved mem dir" "registry:projects.tsv" bash $S/routing.sh --dump
ng "in-repo docs/smithy is NOT consulted" "model=fable" bash $S/routing.sh review
bash $S/paths.sh unset-mem >/dev/null
t "unregistering restores in-repo config" "model=fable" bash $S/routing.sh review

echo "--- introspection surfaces ---"
g "--roles lists the roles"            "mechanical"   bash $S/routing.sh --roles
g "--models lists tier names"          "flagship"     bash $S/routing.sh --models
g "--models lists id patterns"         "pattern"      bash $S/routing.sh --models
g "--models lists efforts"             "efforts:"     bash $S/routing.sh --models
g "--dump shows harness"               "harness:"     bash $S/routing.sh --dump
g "--dump lists config layers"         "config layer" bash $S/routing.sh --dump
bash $S/routing.sh nonsense-role >/dev/null 2>&1 && { echo "FAIL! unknown role should exit nonzero"; fails=$((fails+1)); } || echo "PASS  unknown role exits nonzero"

echo "=== FAILURES: $fails ==="
exit $fails
