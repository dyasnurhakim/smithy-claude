# Harness Adaptation — Claude Code & Codex CLI

Smithy runs on two harnesses. The protocol (creed, memory, envelope,
dispatch discipline) is identical; the MECHANICS differ. Detect once per
session and adapt per this file.

## Detection

You know which harness you are: Claude Code sessions have the Agent/Skill
tools and plugin hooks; Codex sessions read AGENTS.md and use
spawn_agent/wait_agent/close_agent. If genuinely unsure, ask the user.
Record the harness in `docs/smithy/config.json` (`"harness": "claude" |
"codex"`) via `/smithy:calibrate` — routing.sh reads it.

## Model families & tier translation

| Tier | Claude Code | Codex (GPT-5.6) | Roles at this tier (defaults) |
|---|---|---|---|
| flagship | `fable` (or `opus`) | `sol` | planning, review, debugging |
| workhorse | `sonnet` | `terra` | research, implementation, testing |
| fast | `haiku` | `luna` | mechanical |

`routing.sh` translates automatically: with `harness: codex`, a config that
says `opus` resolves to `sol`, `sonnet`→`terra`, `haiku`→`luna` (and the
reverse under claude: `sol`→`opus`, `terra`→`sonnet`, `luna`→`haiku`).
Write configs in either vocabulary; the active harness gets its own family.

**Older GPT generations** (gpt-5.5, gpt-5.4, gpt-5.5-codex, …): set the
explicit id per role — any `gpt-*` id passes through unchanged under the
codex harness. Under claude, a `gpt-*` id can't dispatch, so routing falls
back to that role's default (with a warning). Tier translation only applies
to the named trio; explicit ids are taken literally.
Model availability still varies by account — calibrate's probe rule stands.

## Subagent dispatch

| Concern | Claude Code | Codex CLI |
|---|---|---|
| Enable | built in | `~/.codex/config.toml`: `[features]` `multi_agent = true` |
| Dispatch | Agent tool, `subagent_type: smithy:<agent>`, per-dispatch `model` param | `spawn_agent` with the agent .md file path given as instructions to read first; `wait_agent` for results; **`close_agent` when done — always** |
| Parallel batch | multiple Agent calls in ONE message | multiple `spawn_agent` calls, then `wait_agent` each |
| Per-dispatch model | supported (`model` param) | not guaranteed — if the harness can't set a model per agent, the session model applies and the routing table's effort banner still carries intent; say so in the report |
| Registered agents | plugin `agents/` auto-registered | NOT auto-registered — the dispatch prompt must name the agent file path (`agents/forger.md` etc.) as binding instructions |

Everything else in `references/dispatch.md` is harness-neutral: briefs,
envelopes, statuses, file handoffs, retry/escalation, persona overlays.

## What degrades under Codex — and what compensates

- **Hooks do not run** (SessionStart digest, PreToolUse guard). The guard's
  git/destructive protection is therefore PROMPT-LEVEL only: creed §6 is
  the enforcement. Treat every rule there as if the hook would block it —
  and tell the user once per session that the deterministic layer is off.
  `scripts/guard.sh check "<command>"` still works manually — use it before
  any command you're unsure about.
- **Skills are not auto-routed.** AGENTS.md (repo root) carries the digest;
  read `skills/using-smithy/SKILL.md` at session start, then read each
  skill's SKILL.md when its trigger fires — same files, manual loading.
- **Scripts all work** (bash + git + python3): ledger, routing, envelope,
  review-package, worktree, stack-detect, init-memory are harness-neutral.
- **Sandbox limits** (Codex app/cloud): detached HEAD or managed worktrees
  can block branch/push. Detect before branching:
  `git rev-parse --git-dir` vs `--git-common-dir` differing → linked
  worktree; empty `git branch --show-current` → detached HEAD. Then commit
  work, and hand branch/push to the user's native controls.

## Honesty flag

The Codex port is structurally faithful (mirrors superpowers' shipped
adapter) but NOT yet live-tested under a Codex session. First real run:
verify multi_agent dispatch works with the agent-file-as-instructions
pattern, and report gaps via the repo's issues.
