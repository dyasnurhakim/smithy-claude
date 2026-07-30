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

Persona overlays: every agent type can carry one (see
`${CLAUDE_PLUGIN_ROOT}/references/persona-modes.md` — builders get
engineer + at most one domain specialist; tester suite-matched; annealer
symptom-matched; inspector contextual). The brief's `## Persona` section
names the file(s); the agent adapts per its mode.

- Pass `model` as the Agent tool's per-dispatch `model` parameter. It overrides
  the agent's frontmatter default. If `model=inherit`, omit the parameter.
- Model tiers, cheapest to most capable — Claude Code: `haiku` < `sonnet` <
  `opus` < `fable`; Codex (GPT-5.6): `luna` < `terra` < `sol`, plus explicit
  older ids (`gpt-5.5`, `gpt-5.4`, …). routing.sh translates between the
  families per `${CLAUDE_PLUGIN_ROOT}/references/harness.md`. Availability
  depends on the account — if a dispatch is rejected, tell the user, fall
  back one tier, and suggest `/smithy:calibrate`.
- `effort` is NOT a dispatch parameter. Prepend the matching banner to the
  subagent prompt:

| effort | banner to prepend |
|---|---|
| low | "Effort: LOW. Be brief and mechanical. No exploration beyond the brief." |
| medium | "Effort: MEDIUM. Think through edge cases before acting." |
| high | "Effort: HIGH. Think hard. Enumerate hypotheses/alternatives before committing to one." |
| xhigh | "Effort: XHIGH. Think very hard. Explore the solution space broadly before narrowing, and justify the paths you did not take." |
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
key_facts:
  - <carried forward from prior reports — or empty list []>
concerns: []
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
## Persona (optional — selection per ${CLAUDE_PLUGIN_ROOT}/references/persona-modes.md)
- <persona file path(s), max per the mode table — e.g. masters/engineer.md + masters/security.md>
## Report
Write your report to: $SMITHY_MEM/jobs/<slug>/reports/task-N-impl.md
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

Per-task reports are TRANSIENT: they exist for machine-read status, review
packages, and fix cycles — at forge exit they are consolidated into ONE
`reports/forge-report.md` and the per-task files are deleted.

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
  requirement (RED), then the minimal implementation (GREEN).`
- The jigsmith's report adds a **TDD evidence** section: per requirement,
  verbatim RED output, verbatim GREEN output, and the stage evidence.
- NEEDS_CONTEXT on an untestable requirement is a brief defect: fix the brief
  (blueprint) rather than pressuring the agent to implement without a jig.

Three config keys shape HOW the loop runs. Read all three through
`config.sh get` (never a raw config file — that misses the global layer):

| Key | Values | Effect on the brief |
|---|---|---|
| `implementation.tdd_level` | `minimal` \| `balanced` \| `max` | how many tests each requirement earns |
| `implementation.tdd_commits` | `git` \| `local` | whether each stage is committed |
| `implementation.max_fix_cycles` | int (default 2) | controller review→fix budget, §6 |

**`tdd_level`** — append the matching line to the brief. The loop ordering
never changes; only the breadth of what RED covers:

| level | brief line |
|---|---|
| minimal | "TDD level: MINIMAL. One test per requirement — the primary behaviour, plus the single failure mode that would most likely ship a bug. Do not enumerate edge cases; the bar is 'the software demonstrably works'." |
| balanced | "TDD level: BALANCED. One test per requirement's primary behaviour, plus its realistic edge cases and error paths. Skip combinatorial permutations." |
| max | "TDD level: MAX. Exhaustive: primary behaviour, boundaries, error paths, invariants, and adversarial cases (persona hunt-lists become RED cases). Prefer more small tests over fewer broad ones." |

**`tdd_commits`** — this one changes what counts as EVIDENCE, so the
controller's verification step changes with it:

| value | brief line | how the controller verifies ordering |
|---|---|---|
| git | "TDD commits: GIT. Commit each stage — `test:` at RED, `feat:`/`fix:` at GREEN, `refactor:` if you refactor." | `git log --oneline <base>..HEAD` — `test:` precedes its `feat:`/`fix:` per requirement. Machine-checkable, independent of the agent's own account. |
| local | "TDD commits: LOCAL. Do NOT commit. Leave every change in the working tree, and record each stage in the stage log named in your Report section." | Read the stage log + the report's verbatim RED/GREEN blocks, and diff the working tree. |

`local` is the right choice when the user does not want stage commits in the
history, when no commit grant exists, or inside a scratch worktree that will be
squashed anyway. **Be honest about its cost:** `git log` ordering is the only
TDD evidence the controller does not have to take on trust, and `local` removes
it — the inspector is then reviewing the agent's own account of itself. Default
to `git`; when a user picks `local`, say this once and move on.
In `local` mode forge's commit-grant precondition does not apply (nothing
commits), and the stage log lives at
`$SMITHY_MEM/jobs/<slug>/reports/raw/task-N-tdd-stages.md`.

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
- **State is isolated by a LANE, automatically.** `worktree.sh create` opens a
  state lane named `<job>-<task>` and drops a `.smithy-lane` marker in the
  checkout, so `ledger.sh` run inside that worktree appends to
  `$SMITHY_MEM/lanes/<job>-<task>/ledger.md` instead of the shared one. N
  agents logging at once therefore cannot interleave the project ledger or
  overwrite each other's STATE.md. Reads still return the lane's events
  merged over the project's, so an agent resuming after compaction sees the
  whole history. The agent needs to know nothing about any of this.
- **Lanes are merged after the batch LANDS, not when a worktree is removed.**
  `lane.sh merge <lane>` folds a lane's events into the project ledger in
  timestamp order and appends its decisions; `lane.sh merge-all` does every
  lane at once. Work that was rolled back gets `lane.sh abandon` instead —
  its events never enter the ledger. `worktree.sh remove` deliberately does
  neither: it reports the unmerged lane and leaves the choice to you, because
  a removed checkout is disposable and a discarded event log is not.
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
  to the brief. The budget is `implementation.max_fix_cycles` per unit
  (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get implementation.max_fix_cycles`;
  default 2, applies to forger AND jigsmith alike); then escalate to the user
  with both reports. A budget of 0 means "never auto-fix — escalate on the
  first REJECTED".
- NEEDS_CONTEXT twice on the same question → the question goes to the user.
- Repeated BLOCKED → consider one model-tier bump (e.g. sonnet→opus) for the
  retry, then escalate.

## 7. Ledger

After every dispatch resolves:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append <phase> <job> <unit> <STATUS> <report-path>`
