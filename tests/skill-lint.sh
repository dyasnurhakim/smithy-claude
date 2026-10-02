#!/usr/bin/env bash
# Lint for smithy's prompt files. Run: bash tests/skill-lint.sh
# Checks the rules in references/skill-shape.md that a script can check:
# layout, size, links that point at real files, and conventions that drift.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
fails=0
bad() { printf 'FAIL! %s\n' "$1"; fails=$((fails + 1)); }
ok()  { printf 'PASS  %s\n' "$1"; }

ROUTER=skills/using-smithy/SKILL.md

echo "--- every SKILL.md has the shared shape ---"
for f in skills/*/SKILL.md; do
  n="$(wc -l < "$f")"
  [ "$n" -le 300 ] || bad "$f is $n lines (max 300)"
  grep -qE '^description: ".*"$' "$f" || bad "$f: description must be one quoted line"
  [ "$f" = "$ROUTER" ] && continue
  for h in '## Start' '## Needs' '## Steps' '## Done when' '## Output'; do
    grep -q "^$h" "$f" || bad "$f: missing section '$h'"
  done
  grep -q 'scripts/start.sh' "$f" || bad "$f: Start does not call start.sh"
  grep -qE '^Next: ' "$f" || grep -qE '`Next: ' "$f" || bad "$f: no 'Next:' line"
done
ok "shape checked for $(ls skills/*/SKILL.md | wc -l) skills"

echo "--- every file a prompt points to exists ---"
PROMPTS="$(ls skills/*/SKILL.md agents/*.md references/*.md commands/*.md skills/*/references/*.md references/personas/*/*.md 2>/dev/null)"
missing=0
for f in $PROMPTS; do
  for p in $(grep -oE '(references|scripts|skills|agents|defaults)/[A-Za-z0-9_./-]+\.(md|sh|json|py)' "$f" | sort -u); do
    [ -e "$p" ] || { bad "$f points to $p, which does not exist"; missing=$((missing + 1)); }
  done
done
[ "$missing" -eq 0 ] && ok "all referenced files exist"

echo "--- conventions that used to drift ---"
hits="$(grep -ln 'docs/smithy' skills/*/SKILL.md agents/*.md 2>/dev/null)"
[ -z "$hits" ] && ok "no hard-coded docs/smithy in skills/agents" || bad "hard-coded docs/smithy in: $hits"

for f in skills/*/SKILL.md agents/*.md; do
  if grep -qiE 'fix (cycle|round)' "$f" && ! grep -q 'max_fix_cycles' "$f"; then
    bad "$f talks about fix rounds but never names max_fix_cycles"
  fi
done
ok "fix-round budgets checked"

hits="$(grep -lwiE 'opus|sonnet|haiku|fable' skills/*/SKILL.md | grep -v -e skills/calibrate/ || true)"
[ -z "$hits" ] && ok "skills name routing roles, not models" || bad "model names in: $hits"

hits="$(grep -lE 'tdd_commits.{0,40}\b(git|local)\b' skills/*/SKILL.md agents/*.md references/*.md | grep -v -e skills/jig/ -e skills/calibrate/ || true)"
[ -z "$hits" ] && ok "old tdd_commits names only in jig/calibrate" || bad "old tdd_commits names (git/local) in: $hits"

echo "--- agents ---"
# Agents use a DENY-list, not a tools: allow-list. In Claude Code 2.1.x an
# "mcp__*" wildcard in tools: grants nothing (checked live), so an allow-list
# would cut agents off from MCP lookup tools. No tools: line = inherit all
# tools (MCP included); disallowedTools removes the risky ones.
for f in agents/*.md; do
  grep -q '^tools:' "$f" && bad "$f: has a tools: allow-list (it would hide MCP tools) — use disallowedTools"
  grep -qE '^disallowedTools: .*\bAgent\b' "$f" || bad "$f: disallowedTools must include Agent (agents never dispatch agents)"
  grep -q 'Self-check\|self-check\|creed' "$f" || bad "$f: never mentions the creed"
done
for f in agents/inspector.md agents/annealer.md; do
  grep -qE '^disallowedTools: .*\bWrite\b.*\bEdit\b' "$f" || bad "$f is read-only: disallowedTools must include Write and Edit"
done
ok "agent tool lists checked"

echo "--- manifests agree on the version ---"
v1="$(python3 -c "import json;print(json.load(open('.claude-plugin/plugin.json'))['version'])")"
v2="$(python3 -c "import json;d=json.load(open('.claude-plugin/marketplace.json'));print([p['version'] for p in d['plugins'] if p['name']=='smithy'][0])")"
v3="$(python3 -c "import json;print(json.load(open('.codex-plugin/plugin.json'))['version'])")"
[ "$v1" = "$v2" ] && [ "$v2" = "$v3" ] && ok "version $v1 in all three manifests" || bad "versions differ: plugin=$v1 marketplace=$v2 codex=$v3"

echo
echo "=== FAILURES: $fails ==="
exit "$fails"
