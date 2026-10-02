# Harness Adaptation — Claude Code & Codex CLI

Smithy runs on two harnesses (the program that runs the model and its
tools). The rules — creed, memory, envelope, dispatch — are the same on
both. The MECHANICS differ. Work out which harness you are on once per
session, then follow this file.

```
                 Claude Code                 Codex CLI
skills      auto-routed by plugin       read SKILL.md by hand (AGENTS.md)
agents      Agent tool, registered      spawn_agent + agent file as instructions
hooks       digest + 3 guard hooks      NONE — you enforce the rules yourself
scripts     bash + git + python3        the same scripts, the same behavior
```

## Detection

You know which you are: Claude Code sessions have the Agent and Skill tools
and plugin hooks; Codex sessions read AGENTS.md and use
`spawn_agent` / `wait_agent` / `close_agent`. If truly unsure, ask the user.
Record the harness with `/smithy:calibrate` (`"harness": "claude" | "codex"`)
— in `<memory>/config.json` for one project, or in `$SMITHY_HOME/config.json`
when every project on this machine uses the same harness. `routing.sh`
reads whichever layer wins.

## Model families and tiers

The model list is DATA in `${CLAUDE_PLUGIN_ROOT}/defaults/models.json` — never a list inside a
script. `routing.sh --models` prints what the active harness accepts; use
that, not a list you remember.

| Tier | Claude Code | Codex (GPT-5.6) | Roles at this tier (defaults) |
|---|---|---|---|
| `flagship` | `fable`, `opus` | `sol` | planning, review, debugging |
| `workhorse` | `sonnet` | `terra` | research, implementation, testing |
| `fast` | `haiku` | `luna` | mechanical |

A config value can be any of four things, tried in this order:

1. **A tier name** (`flagship` / `workhorse` / `fast`) → the active harness's
   current model for that tier. The shipped defaults use these, so a new
   model release needs no edit anywhere.
2. **A name native to the active harness** → used as is.
3. **A name from the other harness** → translated BY TIER (`opus`→`sol`
   under codex; `terra`→`sonnet` under claude). Write configs in either set
   of names.
4. **Any id matching the harness's `id_patterns`** → passed through as is.
   `claude-*`, `opus*`, `sonnet*`, `haiku*`, `fable*` under claude; `gpt-*`,
   `o[0-9]*`, `codex*`, `sol*`, `terra*`, `luna*` under codex. This covers
   **older models** (`gpt-5.5`, `gpt-5.4-codex`) and **unreleased ones**
   (`claude-opus-6`, `gpt-7`) with no plugin change.

A value that only matches the OTHER harness's patterns cannot run here, so
routing falls back to that role's default and warns. An unknown value does
the same. `--dump` shows both as `defaults(harness-fallback)` in the SOURCE
column.

**A whole new family** (a third harness, a renamed tier) goes in
`$SMITHY_HOME/models.json`, which is merged over the plugin's list — again
no plugin edit.

The list only checks that a name is WELL-FORMED. **Whether an account can
use a model still varies, so calibrate's test dispatch is what proves a
model works.** That split is what makes the loose patterns safe.

## Subagent dispatch

| Concern | Claude Code | Codex CLI |
|---|---|---|
| Turn on | built in | `~/.codex/config.toml`: `[features]` `multi_agent = true` |
| Dispatch | Agent tool, `subagent_type: smithy:<agent>`, `model` parameter per dispatch | `spawn_agent` with the agent file path as instructions to read first; `wait_agent` for results; **always `close_agent` when done** |
| Parallel batch | several Agent calls in ONE message | several `spawn_agent` calls, then `wait_agent` on each |
| Model per dispatch | supported (`model` parameter) | not guaranteed — if a model cannot be set per agent, the session model is used and the effort banner still carries the intent; say so in the report |
| Agents registered | plugin `agents/` registered automatically | NOT registered — the prompt must name the agent file (`${CLAUDE_PLUGIN_ROOT}/agents/forger.md` etc.) as binding instructions |
| Lookup tools (MCP) | agents have no `tools:` allow-list (a `disallowedTools` deny-list instead), so they inherit installed MCP tools and may make read-only lookups (creed §10) | UNVERIFIED whether `spawn_agent` workers can reach MCP tools. Tell agents: "use lookup tools if available, else Read/Grep" |

Everything else in `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` is the same on both: briefs,
envelopes, statuses, file hand-offs, retries and escalation, persona overlays.

## What is weaker under Codex — and what makes up for it

- **No hooks run** — not the session-start digest, not `guard.sh`, not
  `route-guard.sh`, not `mcp-guard.sh`. Three safety layers become
  PROMPT-LEVEL only (you enforce them; nothing will stop you):
  - *git and destructive commands* — creed §6 is the rule. Treat every line
    there as if a hook would block it. `${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh check "<command>"`
    still works by hand — use it before any command you are unsure about.
  - *model and effort routing* — `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §1 is the rule.
    Nothing fixes a forgotten `model` or a missing effort banner, so resolve
    routing before EVERY dispatch and apply both halves yourself.
    `${CLAUDE_PLUGIN_ROOT}/scripts/route-guard.sh table` prints what each agent should run as.
  - *lookup tools that change things* — creed §10 "reading is free,
    changing needs a yes" is enforced only by you. Before any tool call that
    sends, creates, updates or deletes, ask the user.
  Tell the user once per session that these three layers are off.
- **Skills are not routed for you.** AGENTS.md (repo root) carries the
  digest. Read `${CLAUDE_PLUGIN_ROOT}/skills/using-smithy/SKILL.md` at session start, then each
  skill's SKILL.md when its trigger fires — the same files, loaded by hand.
- **Scripts all work the same** (bash + git + python3): `start.sh`, `tdd-snap.sh`,
  paths, config, ledger, routing, envelope, review-package, worktree, lane,
  stack-detect, init-memory. `start.sh` and `tdd-snap.sh` behave exactly as
  on Claude Code: bash + git, no hooks needed. Every skill still begins
  with `${CLAUDE_PLUGIN_ROOT}/scripts/start.sh` — memory need not be inside the repo.
- **Sandbox limits** (Codex app/cloud): a detached HEAD or managed worktrees
  can block branching or pushing. Check before branching:
  `git rev-parse --git-dir` differs from `--git-common-dir` → a linked
  worktree; empty `git branch --show-current` → detached HEAD. Then commit
  the work, and leave branch/push to the user's own controls.

## Honesty flag

The Codex port follows the same structure as superpowers' shipped adapter,
but has NOT yet been tested in a live Codex session. On the first real run,
check that multi_agent dispatch works with the agent-file-as-instructions
pattern, check whether workers can use MCP tools, and report gaps in the
repo's issues.
