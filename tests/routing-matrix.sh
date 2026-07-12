#!/usr/bin/env bash
set -u
S=/home/dyasnurhakim/claude-agent/smithy/scripts
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
cd "$D" && git init -q -b main && mkdir -p docs/smithy
fails=0
t() { # t <desc> <expect-substr> <cmd...>
  local desc="$1" want="$2"; shift 2
  got="$("$@" 2>/dev/null)"
  case "$got" in *"$want"*) printf 'PASS  %-45s %s\n' "$desc" "$got" ;;
  *) printf 'FAIL! %-45s want~%s got=%s\n' "$desc" "$want" "$got"; fails=$((fails+1)) ;; esac
}

printf '{"smithy_config_version":1,"routing":{}}' > docs/smithy/config.json
t "claude default: review=opus"        "model=opus"   bash $S/routing.sh review
t "claude default: testing=sonnet"     "model=sonnet" bash $S/routing.sh testing

printf '{"smithy_config_version":1,"harness":"codex","routing":{}}' > docs/smithy/config.json
t "codex: review opus->sol"            "model=sol"    bash $S/routing.sh review
t "codex: testing sonnet->terra"       "model=terra"  bash $S/routing.sh testing
t "codex: mechanical haiku->luna"      "model=luna"   bash $S/routing.sh mechanical

printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"sol","effort":"max"}}}' > docs/smithy/config.json
t "codex: native sol accepted"         "model=sol effort=max" bash $S/routing.sh review

printf '{"smithy_config_version":1,"routing":{"review":{"model":"terra","effort":"high"}}}' > docs/smithy/config.json
t "claude: terra translates->sonnet"   "model=sonnet" bash $S/routing.sh review

printf '{"smithy_config_version":1,"harness":"gemini","routing":{}}' > docs/smithy/config.json
t "unknown harness falls back claude"  "model=opus"   bash $S/routing.sh review

printf '{"smithy_config_version":1,"harness":"codex","routing":{"planning":{"model":"fable","effort":"max"}}}' > docs/smithy/config.json
t "codex: fable->sol"                  "model=sol"    bash $S/routing.sh planning

printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"gpt-5.5","effort":"high"}}}' > docs/smithy/config.json
t "codex: older gpt-5.5 passes through"  "model=gpt-5.5" bash $S/routing.sh review
printf '{"smithy_config_version":1,"harness":"codex","routing":{"testing":{"model":"gpt-5.4-codex","effort":"low"}}}' > docs/smithy/config.json
t "codex: gpt-5.4-codex passes through"  "model=gpt-5.4-codex" bash $S/routing.sh testing
printf '{"smithy_config_version":1,"routing":{"review":{"model":"gpt-5.5","effort":"high"}}}' > docs/smithy/config.json
t "claude: gpt-5.5 falls back to opus"   "model=opus"   bash $S/routing.sh review
printf '{"smithy_config_version":1,"harness":"codex","routing":{"review":{"model":"totally-fake","effort":"high"}}}' > docs/smithy/config.json
t "invalid model name rejected at entry" "model=sol"    bash $S/routing.sh review

printf '{"smithy_config_version":1,"harness":"codex","routing":{}}' > docs/smithy/config.json
bash $S/routing.sh --dump | head -2 | grep -q 'harness: codex' && echo "PASS  --dump shows harness" || { echo "FAIL! dump harness"; fails=$((fails+1)); }
bash $S/routing.sh --dump | grep -q 'translated' && echo "PASS  dump marks translations" || { echo "FAIL! translation marker"; fails=$((fails+1)); }

echo "=== FAILURES: $fails ==="
exit $fails
