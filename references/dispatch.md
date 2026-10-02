# Smithy Dispatch — how skills hand work to agents

Read this only in skills that dispatch agents. It covers: which model,
what goes in the prompt, the brief, statuses, the review, and retries.

| Agent | Routing role | Writes | Used by |
|---|---|---|---|
| `forger` | implementation | code + tests, one commit | forge, strike, anneal (fix) |
| `jigsmith` | implementation | tests first, then code, one commit | forge/jig when TDD is on |
| `inspector` | review | nothing (report only) | inspect, forge/strike (final review), guild |
| `annealer` | debugging | nothing (report only) | anneal |
| `temperer` | testing | test files and test config only | ring-test, wield, proof, hone |

All five can also use **read-only MCP lookup tools** (memory, code graph,
docs — creed §10). Tools that change things make Claude Code ask the user
first (the `mcp-guard` hook).

## 1. Model and effort

Before every dispatch:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh <role>   → model=sonnet effort=medium
```

Roles: `research planning implementation review debugging testing mechanical`.

- Pass `model` as the Agent tool's `model` parameter (omit it when the value
  is `inherit`). If the account rejects the model: tell the user, go one
  tier down, suggest `/smithy:calibrate`.
- `effort` is not a parameter. Put the effort banner at the top of the
  prompt. The banner text lives in `${CLAUDE_PLUGIN_ROOT}/defaults/models.json` → `effort_banners`;
  `routing.sh --models` prints what is in force.
- **Claude Code enforces this with a hook** (`route-guard.sh`): it fixes the
  model and banner of every smithy dispatch to match config, and leaves a
  `[smithy-route-guard]` note when it does. Treat a fix as a sign you
  drifted. Do not re-dispatch around it. To change routing, use
  `/smithy:calibrate`. The only per-task override: a line
  `smithy-role: <role>` in the brief (a role, never a raw model).
- The hook REPORTS but cannot fix two cases: a routed model this harness
  won't accept, and a config whose `harness` is not the one running. Both →
  `/smithy:calibrate`.
- Off Claude Code (Codex) there are no hooks; follow this section by hand —
  see `${CLAUDE_PLUGIN_ROOT}/references/harness.md`.

## 2. The prompt holds paths, not text

The dispatch prompt contains ONLY:

1. the effort banner;
2. absolute paths to: the brief, `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, and the report file
   the agent must write;
3. one line naming the job and unit ("Job user-auth, task 3").

Never paste a brief, a report or chat history into a prompt. The agent
writes its report to the file and returns only: status, one-line summary,
concerns.

## 3. The brief

Every brief and report starts with the envelope (`${CLAUDE_PLUGIN_ROOT}/references/envelope.md`).
**Carry forward:** copy every open `key_facts` / `concerns` item from the
reports you used into the next brief's envelope.

Before writing briefs, do ONE lookup (creed §10) on the files and topic, and
put what matters (past decisions, past bugs, callers) into `key_facts` with
its source (`claude-mem #1234`, `file:line`).

```markdown
---smithy
schema: 1
kind: brief
job: <slug>
unit: task-N
key_facts:
  - <carried forward or from the lookup — or []>
concerns: []
---
# Task N: <title>
## Context files (read these, nothing else)
- path/to/file.ts — why it matters
## Requirements
1. <observable behavior: "returns X when Y", "exits 64 on bad input">
## Verify
- `<command>` → expected: <output/behavior>
## Commit message
<type>: <description>
## Persona (optional — see references/persona-modes.md)
- references/personas/masters/engineer.md
## Report
Write your report to: <memory>/jobs/<slug>/reports/task-N-impl.md
```

TDD tasks get extra lines in the brief — the exact text is in
`/smithy:jig` (skills/jig/SKILL.md § Brief lines), the one place TDD
rules live.

## 4. Statuses

| Status | Meaning | What the controller does |
|---|---|---|
| DONE | requirements met, checks green, self-check passed | next task |
| DONE_WITH_CONCERNS | done, with worries listed | read the report; sort each concern (blocking → fix now; other → carry to the final review) |
| NEEDS_CONTEXT | one exact question | answer from spec/plan, or ask the user; re-dispatch with the answer |
| BLOCKED | cannot proceed (env, permission, contradiction) | fix the cause or ask the user; maybe one model tier up |

Read status from the envelope: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh get <report> status`.
**Broken or missing envelope** (and no `Status:` line) → treat as
DONE_WITH_CONCERNS: read the full report, and mention the format problem on
the next dispatch. Never assume DONE.

## 5. Review — a self-check per task, ONE review per job

```
task 1 ─▶ agent: build → verify → SELF-CHECK → commit ─┐
task 2 ─▶ agent: build → verify → SELF-CHECK → commit ─┼─▶ all tasks done
task 3 ─▶ agent: build → verify → SELF-CHECK → commit ─┘          │
                                                                  ▼
              ONE inspector over the whole job:  BASE ────────▶ HEAD
                                                                  │
                         controller judges findings → fix round(s) → re-review the fix only
```

**Self-check (inside every implementation agent, no extra dispatch).** Each
forger/jigsmith ends with a short checklist in its report: each requirement
→ `file:line`; only brief files touched; verify commands green; no debug
code or stray TODOs; (TDD) `tdd-snap.sh verify` line is `OK`. A failed
item → the agent fixes it before reporting, or reports DONE_WITH_CONCERNS.

**Final review (once, from the main session, after ALL tasks finish).**

1. Build one package from the JOB base to HEAD, with the plan as the brief:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh build <memory>/jobs/<slug>/plan.md <memory>/jobs/<slug>/reports/review-pkg.md <memory>/jobs/<slug>/reports/`
   The third argument is the reports FOLDER (`forge-report.md` does not
   exist yet at review time). Standalone with no recorded base: add
   `--base <ref>` right after `build`.
2. Dispatch ONE `inspector` (role `review`). Its prompt must include:
   **"Do Not Trust the Reports — the implementers' claims are unverified.
   Verify each one against the diff and with read-only checks."** Name the
   TDD commits mode if TDD ran, so it checks the right evidence.
3. The inspector gives two verdicts, each `APPROVED|REJECTED`:
   spec compliance (per task and requirement) and code quality (findings
   with `file:line`, severity Critical/High/Medium/Low, confidence 1–10).
4. You judge the findings (see `/smithy:inspect` § Judging findings) before
   acting on them.

## 6. Fix rounds and escalation

- REJECTED → one fix round: re-dispatch the agent for each affected task
  with the review report path added to its brief. Record the HEAD before
  the round; after it, review ONLY the fix diff (`--base <that sha>`, with
  the reports folder `<memory>/jobs/<slug>/reports/` as the third argument).
- Budget: `implementation.max_fix_cycles` rounds per job
  (`config.sh get implementation.max_fix_cycles`, default 2; `0` = never
  auto-fix, go straight to the user). Budget spent → stop, show both review
  reports, and say why you think it is stuck.
- Same NEEDS_CONTEXT question twice → the user answers it.
- BLOCKED again → one model-tier step up for the retry, then the user.

## 7. Parallel batches (worktrees)

Tasks marked `∥ batch-X` in the plan (blueprint proved they touch different
files) MAY run at the same time. **The user decides, once per batch.**

- Before the batch, re-check the plan's disjointness evidence against the
  files as they are NOW. Any overlap → run that batch one task at a time
  and tell the user why.
- The question to the user includes the plan's one-line disjointness
  evidence.

```
           ┌─ worktree task-2 ─ agent ─ self-check ─┐
integrate ─┤                                         ├─ absorb ─▶ integration branch
           └─ worktree task-3 ─ agent ─ self-check ─┘                    │
                       run the tasks' checks + test suite HERE ◀─────────┘
                                         │ green
                                         ▼
                           land on the working branch ─▶ (final review later)
```

- `worktree.sh integrate <job>` first; `worktree.sh create <job> <task>` per
  task (it also opens a state lane, so ledgers never collide); confirm the
  lanes opened with `lane.sh list` before dispatching; send ALL batch
  dispatches in ONE message; each agent works only in its worktree; reports
  go to the main repo's memory folder (absolute paths).
- TDD tasks: run `tdd-snap.sh verify <slug> <unit>` INSIDE the task's
  worktree (cd there) before `absorb`/`remove` — run from the main worktree
  it fails.
- When each agent is DONE: `worktree.sh absorb <job> <task>` into the
  integration branch, then `worktree.sh remove <path> --force`.
- Run the batch's verify commands and the test suite in the integration
  worktree. Failure → `/smithy:anneal` there; the working branch stays clean.
- Green → `worktree.sh land <job>`. A merge conflict means the batch was not
  really separate: stop, tell the user which files, re-run that task alone.
- After landing: `lane.sh merge-all` (it also merges the
  `<job>-integration` lane that `worktree.sh integrate` opens); rolled-back
  work → `lane.sh abandon <lane>`. Then rewrite STATE.md yourself.
- Always clean up at batch end: `worktree.sh clean <job>`. Worktrees the
  USER made are never removed — ask.
- Nothing is pushed. Max one batch at a time, ≤4 worktrees.

## 8. Ledger

After each dispatch resolves:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append <skill> <slug> <unit> <STATUS> <report-path>`
