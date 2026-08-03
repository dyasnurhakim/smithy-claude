# Harness Adaptation — Claude Code & Codex CLI

Smithy runs on two harnesses. The protocol (creed, memory, envelope,
dispatch discipline) is identical; the MECHANICS differ. Detect once per
session and adapt per this file.

## Detection

You know which harness you are: Claude Code sessions have the Agent/Skill
tools and plugin hooks; Codex sessions read AGENTS.md and use
spawn_agent/wait_agent/close_agent. If genuinely unsure, ask the user.
Record the harness via `/smithy:calibrate` (`"harness": "claude" | "codex"`) —
in `$SMITHY_MEM/config.json` for one project, or in `$SMITHY_HOME/config.json`
when every project on this machine uses the same harness. routing.sh reads
whichever layer wins.

## Model families & tier translation

The registry is DATA — `defaults/models.json` — never a list in a script.
`routing.sh --models` prints what the active harness accepts; consult that
rather than any list you remember.

| Tier | Claude Code | Codex (GPT-5.6) | Roles at this tier (defaults) |
|---|---|---|---|
| `flagship` | `fable`, `opus` | `sol` | planning, review, debugging |
| `workhorse` | `sonnet` | `terra` | research, implementation, testing |
| `fast` | `haiku` | `luna` | mechanical |

A config value may be any of four things, resolved in this order:

1. **A tier name** (`flagship`/`workhorse`/`fast`) → the active harness's
   current model for that tier. The shipped defaults use these, which is why a
   new model release needs no edit anywhere.
2. **A name native to the active harness** → used verbatim.
3. **A name from another harness** → translated BY TIER (`opus`→`sol` under
   codex; `terra`→`sonnet` under claude). Write configs in either vocabulary.
4. **Any id matching the harness's `id_patterns`** → passed through verbatim.
   `claude-*`, `opus*`, `sonnet*`, `haiku*`, `fable*` under claude; `gpt-*`,
   `o[0-9]*`, `codex*`, `sol*`, `terra*`, `luna*` under codex. This covers both
   **older generations** (`gpt-5.5`, `gpt-5.4-codex`) and **unreleased ones**
   (`claude-opus-6`, `gpt-7`) with zero plugin change.

A value that matches only ANOTHER harness's patterns can't dispatch here, so
routing falls back to that role's default with a warning. An unrecognized value
does the same. Both are visible in `--dump`'s SOURCE column as
`defaults(harness-fallback)`.

**A whole new family** (a third harness, a renamed tier) goes in
`$SMITHY_HOME/models.json`, which deep-merges over the plugin registry — again
no plugin edit.

The registry validates SYNTAX only. **Availability still varies by account, so
calibrate's dispatch probe is what proves a model works** — that split is what
makes the permissive patterns safe.

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

- **Hooks do not run** (SessionStart digest, PreToolUse guard, PreToolUse
  route-guard). Two deterministic layers become PROMPT-LEVEL only:
  - *git/destructive protection* — creed §6 is the enforcement. Treat every
    rule there as if the hook would block it. `scripts/guard.sh check
    "<command>"` still works manually — use it before any command you're
    unsure about.
  - *model/effort routing* — `references/dispatch.md` §1 is the enforcement.
    Nothing will correct a forgotten `model` or a missing effort banner, so
    resolve routing before EVERY dispatch and apply it yourself.
    `scripts/route-guard.sh table` prints what each agent should be running as.
  Tell the user once per session that both deterministic layers are off.
- **Skills are not auto-routed.** AGENTS.md (repo root) carries the digest;
  read `skills/using-smithy/SKILL.md` at session start, then read each
  skill's SKILL.md when its trigger fires — same files, manual loading.
- **Scripts all work** (bash + git + python3): paths, config, ledger, routing,
  envelope, review-package, worktree, stack-detect, init-memory are
  harness-neutral. `paths.sh mem` is the first thing to run in any session —
  memory need not be inside the repo.
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
