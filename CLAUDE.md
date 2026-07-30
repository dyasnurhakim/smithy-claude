# Smithy — Harness Entrypoint

This repository is the smithy dev-pipeline plugin. Under Claude Code it is
installed as a plugin (hooks inject the digest automatically — you likely
don't need this file). Under **Codex CLI** (or any harness reading
AGENTS.md), THIS file is your bootstrap. Today's harness rules:

## Bootstrap (Codex / AGENTS.md harnesses)

1. Read `skills/using-smithy/SKILL.md` — the router: when to use which
   skill, priority rules, red flags. Then read `references/harness.md` —
   how dispatch, models, and safety adapt off Claude Code.
2. When a trigger fires, read that skill's `skills/<name>/SKILL.md` and
   follow it exactly. `${CLAUDE_PLUGIN_ROOT}` in any smithy file = this
   repository's root.
3. Enable subagents in `~/.codex/config.toml`: `[features]`
   `multi_agent = true`. Dispatch per `references/dispatch.md`, adapted per
   harness.md: `spawn_agent` with the agent file (`agents/forger.md`, …) as
   binding instructions, `wait_agent` for results, and ALWAYS `close_agent`
   when an agent finishes.
4. Models: this harness uses the GPT-5.6 family — `sol` (flagship: planning,
   review, debugging), `terra` (workhorse: implementation, testing), `luna`
   (fast: mechanical). `scripts/routing.sh <role>` translates automatically
   once `"harness": "codex"` is set (calibrate skill, global or project layer).
   Model names live in `defaults/models.json`, NOT in any script: tier names
   (`flagship`/`workhorse`/`fast`) and unrecognized-but-matching ids both
   resolve, so new releases need no edit. `routing.sh --models` lists what the
   active harness accepts — never rely on a remembered list.

## Non-negotiables (all harnesses)

- The creed (`references/creed.md`) binds every skill and agent: never
  assume — ask or recommend; evidence before assertion; surgical changes;
  read reference files once per session.
- **No plugin hooks run outside Claude Code**, so the git/destructive guard
  is prompt-level here: treat creed §6 as if a hook would block you —
  no push without a live user yes, no commits without the plan-gate grant,
  no history rewrites, no destructive cloud/DB/fs commands without explicit
  approval. `bash scripts/guard.sh check "<command>"` answers "would this
  be blocked?" — use it when unsure.
- Per-project memory lives at `$SMITHY_MEM`, which is NOT necessarily inside
  the repo. Resolve it with `bash scripts/paths.sh mem` before using any smithy
  path, and never hardcode `docs/smithy` (projects that clean or regenerate
  `docs/` would lose the ledger mid-job). `scripts/init-memory.sh` scaffolds it
  and exits 3 when the location is undecided — that means ASK the user, per
  `references/memory.md` § Location. Trust STATE.md + ledger + git log over
  recollection.

## Working on smithy itself

Bash tests: `tests/guard-matrix.sh`, `tests/worktree-matrix.sh`,
`tests/routing-matrix.sh`, `tests/paths-matrix.sh`, `tests/lane-matrix.sh` —
all must stay green.
`scripts/paths.sh` is sourced by the PreToolUse guard hook, so it must stay pure
bash for resolution rules 1-4 (no interpreter spawn) and must never enable
`errexit` when sourced.

SKILL.md budget ≤300 lines. Skill descriptions are YAML-quoted (they contain
colons). Version bumps touch `.claude-plugin/plugin.json`,
`.claude-plugin/marketplace.json`, and `.codex-plugin/plugin.json` together.
