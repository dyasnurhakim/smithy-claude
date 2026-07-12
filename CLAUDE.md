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
   when `docs/smithy/config.json` has `"harness": "codex"` — set it once via
   the calibrate skill.

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
- Per-project memory lives in the TARGET project's `docs/smithy/`
  (`scripts/init-memory.sh`); trust STATE.md + ledger + git log over
  recollection.

## Working on smithy itself

Bash tests: `tests/guard-matrix.sh`, `tests/worktree-matrix.sh`,
`tests/routing-matrix.sh` — all must stay green. SKILL.md budget ≤300
lines. Skill descriptions are YAML-quoted (they contain colons). Version
bumps touch `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`,
and `.codex-plugin/plugin.json` together.
