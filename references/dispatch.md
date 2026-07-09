# Smithy Dispatch Protocol

How skills dispatch the five smithy agents with routed models, bounded
context, and verifiable output.

| Agent | Role (routing) | Writes? | Dispatched by |
|---|---|---|---|
| `forger` | implementation | source + tests | forge, anneal (fix step) |
| `jigsmith` | implementation | tests then source (TDD, RED→GREEN per requirement) | forge/jig when `implementation.tdd` selects TDD |
| `inspector` | review | nothing (read-only + report) | inspect, forge (per task) |
| `annealer` | debugging | nothing (read-only + report) | anneal |
| `temperer` | testing | test files/configs only | ring-test, wield, proof, hone |

## 1. Resolve routing

Before every dispatch:

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh <role>
→ model=sonnet effort=medium
```

Roles: `research planning implementation review debugging testing mechanical`.

- Pass `model` as the Agent tool's per-dispatch `model` parameter. It overrides
  the agent's frontmatter default. If `model=inherit`, omit the parameter.
- Model tiers, cheapest to most capable: `haiku` < `sonnet` < `opus` < `fable`
  (Claude 5, Mythos-class). Fable availability depends on the account — if a
  fable dispatch is rejected, tell the user and fall back to opus for that
  dispatch; suggest `/smithy:calibrate` to change the route.
- `effort` is NOT a dispatch parameter. Prepend the matching banner to the
  subagent prompt:

| effort | banner to prepend |
|---|---|
| low | "Effort: LOW. Be brief and mechanical. No exploration beyond the brief." |
| medium | "Effort: MEDIUM. Think through edge cases before acting." |
| high | "Effort: HIGH. Think hard. Enumerate hypotheses/alternatives before committing to one." |
| max | "Effort: MAX. Ultrathink. Exhaust alternatives; steelman the opposite conclusion before finalizing." |

## 2. Hand over files, not text

The dispatch prompt contains ONLY:

1. The effort banner.
2. Absolute paths to: the brief/context file, `${CLAUDE_PLUGIN_ROOT}/references/creed.md`,
   and the report output path the agent must write to.
3. One sentence naming the job and unit (e.g. "Job user-auth, task 3").

Never paste the brief's contents, prior reports, or conversation history into
the prompt. Never let the agent return the full report inline — it writes the
report file and returns only: status, one-line summary, concerns.

## 3. Brief template (written by blueprint/anneal/test skills)

Every brief and report opens with the smithy envelope — the full contract is
`${CLAUDE_PLUGIN_ROOT}/references/envelope.md` (read it once per session).
**Controller rule:** copy every unresolved `key_facts`/`concerns` item from
consumed reports forward into the next brief's envelope.

```markdown
---smithy
schema: 1
kind: brief
job: <slug>
unit: task-N
artifacts:
  - docs/smithy/jobs/<slug>/briefs/task-N.md
key_facts:
  - <carried forward from prior reports — or empty list []>
concerns: []
next_action: "implement task-N"
---
# Task N: <title>
## Context files (read these, nothing else)
- path/to/file.ts — why it matters
## Requirements
- <numbered, testable requirements>
## Verify
- `<command>` → expected: <output/behavior>
## Commit message
<type>: <description>
## Report
Write your report to: docs/smithy/jobs/<slug>/reports/task-N-impl.md
Open it with a smithy envelope (kind: impl-report) per your agent
instructions, then the body with `Status: <STATUS>` as its first line.
Status MUST be one of: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
```

## 4. Status vocabulary and controller responses

| Status | Meaning | Controller response |
|---|---|---|
| DONE | All requirements met, verify commands ran green | Proceed to review |
| DONE_WITH_CONCERNS | Done, but concerns listed | Triage each concern before proceeding |
| NEEDS_CONTEXT | Blocked on a specific question | Answer it (or ask the user), re-dispatch |
| BLOCKED | Cannot proceed (env, permissions, contradiction) | Resolve or escalate to user; consider model bump |

Read a report's status from its envelope:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh get <report> status`.

**Defensive rule:** if a report's envelope is missing/unparseable (and no
`Status:` body line rescues it), treat it as DONE_WITH_CONCERNS — read the
full report before proceeding, and note the format violation when
re-dispatching that agent. Never crash the pipeline on a malformed report;
never assume it means DONE.

## 4b. TDD variant (jigsmith)

When `implementation.tdd` resolves to TDD for a task (see `/smithy:jig`):
- The brief gains: `TDD mode: write the failing test FIRST for each
  requirement (RED), then the minimal implementation (GREEN), commit per stage.`
- The jigsmith's report adds a **TDD evidence** section: per requirement,
  verbatim RED output, verbatim GREEN output, and the stage commits.
- The controller verifies commit ordering from `git log <base>..HEAD`
  (`test:` before `feat:`/`fix:` per requirement) — evidence, not trust.
- NEEDS_CONTEXT on an untestable requirement is a brief defect: fix the brief
  (blueprint) rather than pressuring the agent to implement without a jig.

## 4c. Parallel dispatch (worktree isolation)

Tasks marked `∥ batch-X` in the plan (blueprint proved them disjoint) MAY
run concurrently — **the user chooses per batch** (parallel vs sequential;
ask once, with the disjointness evidence). When parallel:

- `worktree.sh integrate <job>` first — parallel work merges into an
  INTEGRATION branch, is verified there, and only then lands on the working
  branch (`worktree.sh land <job>`). The working branch never sees
  unverified batch output.
- `worktree.sh create <job> <task>` per task → path + branch
  `smithy/<job>/<task>`; ALL batch agents dispatched in ONE message.
- Each agent works ONLY in its worktree; reports go to the MAIN repo's
  reports dir (absolute paths). Guard grants resolve to the main worktree
  automatically.
- Everything stays LOCAL: task/integration branches are never pushed to
  origin unless the user explicitly asks (each push = its own yes + token).
- Review the branch (`review-package.sh build ... <branch>`) BEFORE
  absorbing; `worktree.sh absorb` merges into integration; a conflict
  aborts cleanly and means the batch was mis-marked — escalate, don't
  hand-resolve.
- **Smithy-created worktrees are ALWAYS removed when their task finishes**
  (`remove --force` post-absorb; `clean <job>` at batch end, integration
  included). Worktrees the USER created are never auto-removed — the script
  refuses them; ask the user: auto-clear or leave.

## 5. Review discipline

- Record BASE before dispatching a forger:
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`
- Build the package from BASE..HEAD (never `HEAD~1` — it silently drops all
  but the last commit):
  `review-package.sh build <brief> <out> [impl-report]`
- The reviewer reads the package file. Its prompt must include:
  **"Do Not Trust the Report — the forger's claims are unverified.
  Verify each one against the diff and by running read-only checks."**
- Two verdicts, each `APPROVED|REJECTED`: (1) spec compliance, per-requirement;
  (2) code quality, findings with `file:line`, severity
  Critical/High/Medium/Low, confidence 1–10.

## 6. Retry and escalation

- REJECTED review → re-dispatch the forger with the review report path added
  to the brief. Maximum 2 fix cycles per unit; then escalate to the user with
  both reports.
- NEEDS_CONTEXT twice on the same question → the question goes to the user.
- Repeated BLOCKED → consider one model-tier bump (e.g. sonnet→opus) for the
  retry, then escalate.

## 7. Ledger

After every dispatch resolves:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append <phase> <job> <unit> <STATUS> <report-path>`
