---
name: smithy
description: "Full pipeline orchestrator (research → plan → build + review → panel → test) with approval gates and ledger resume. Triggers: 'run smithy', 'build end to end', 'full pipeline', resume smithy work."
---

# Smithy — Pipeline Orchestrator

**You orchestrate. You never do phase work yourself.** Each phase runs by
invoking its skill. You read back only statuses, file paths and short
summaries — never paste a file's contents into your context.

```
ASSAY ─[gate]─▶ BLUEPRINT ─[gate: yes = commit grant]─▶ FORGE ─[gate]─▶ GUILD ─▶ TEMPER ─[gate: ship]─▶ IDLE
                                    tasks (self-checked) + ONE review │            │
                                                          NOT_READY ──┘            └── NOT READY
                                                              ▼                          ▼
                                                   STRIKE (known fixes)      ANNEAL (cause unknown)
                                                                             STRIKE (known fixes)
        after a fix lane: back to the exact unit that broke — never the phase start
```

STATE.md phases (`${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`): ASSAY · BLUEPRINT · FORGE ·
STRIKE · ANNEAL · TEMPER · GUILD · IDLE. You own STATE.md between phases.

## Start

1. **The request first.** The user gave none → ask what to build, in one
   question. Pick a short feature slug from the answer.
2. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh smithy <feature-slug>` (the
   same slug you will give assay) — read its summary. Resuming earlier work:
   `start.sh smithy auto`.
3. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`.
   `${CLAUDE_PLUGIN_ROOT}/references/memory.md` § Lanes only when lanes exist or you run two pipelines.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| A goal from the user | use it | ask what to build, in one question |
| An active job (start.sh `state: active=`) | ask: **Resume** (say phase + unit + next action) / **Start new** (the old job stays on disk) / **Abort old** (STATE.md → IDLE; `ledger.sh append smithy <old> abort REJECTED -`) | start at ASSAY |
| Unmerged lanes (start.sh prints them) | read each (`SMITHY_LANE=<name> ledger.sh tail`); merge it if its branch landed, abandon it if the work was rolled back — BEFORE computing where to resume | continue |
| `gates.pause_between_phases` | `config.sh get gates.pause_between_phases` (merges all config layers; never read a config file directly) | default `true` |

## Steps

1. **Find the position.** Resume = recompute from the LEDGER, not memory:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail 30`. The first unit
   without `DONE` / `APPROVED` / `PASS` is where work resumes. Cross-check
   `git log --oneline <base>..HEAD` when a base exists, and scan the job's
   `reports/` for work a crashed session never logged.
   → verify: you can name the phase and unit, with the ledger line before it.

2. **ASSAY** — invoke `/smithy:assay`. Then **[gate]**.
   → verify: `spec.md` exists with no open questions; gate line logged.

3. **BLUEPRINT** — invoke `/smithy:blueprint` (it records the job base once).
   Then **[gate]** — this gate carries the commit grant (Gates, rule 4).
   → verify: `plan.md` + briefs exist; `guard.sh status` shows the grant.

4. **FORGE** — invoke `/smithy:forge`. Agents self-check each task; forge
   runs ONE review of the whole job and its own fix rounds
   (`implementation.max_fix_cycles`). There is no per-task review and no
   gate per task. Then **[gate]**.
   → verify: `forge-report.md` with both review verdicts APPROVED, or the user decided.

5. **GUILD** — runs when `config.sh get review_panel` is `auto` or
   `always`; skipped when `never`. It has no gate of its own; its verdict
   drives the flow. NOT_READY → **STRIKE** with the guild report path
   (Critical/High findings), then re-run only the personas that raised
   findings. Medium/Low deferrals need the user's explicit OK, recorded in
   `decisions.md`. Rounds: `implementation.max_fix_cycles`, then the user.
   → verify: PRODUCTION_READY, the panel is off, or the user decided.

6. **TEMPER** — invoke `/smithy:temper`. NOT READY → Failure routing.
   READY → **[gate: ship it?]**.
   → verify: a READY verdict line in the ledger; ship gate logged.

7. **Exit** — run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh status`. The
   grant names THIS job → `guard.sh revoke` (commit authorization ends with
   the job). It names another job → leave it: there is one grant file per
   project, and that job still needs it. STATE.md: Phase IDLE, next step none.
   Offer `/smithy:handover`.
   → verify: `guard.sh status` shows no grant for this job.

## Gates

At each `[gate]` — skipped only when `gates.pause_between_phases` is
`false`. The commit grant still needs the user's yes even then (creed §6):

1. **Present:** the phase's file path + a ≤5-line summary + what the next
   phase will do + any concerns carried forward.
2. **Ask:** **Approve** (go on) / **Revise** (re-run the phase with the
   user's feedback added to its input) / **Abort** (update STATE.md, stop cleanly).
3. **Log first:** `ledger.sh append gate <slug> <phase> <APPROVED|REJECTED> <file>`
   (`gate` is the one reserved ledger phase that is not a skill name)
   and update STATE.md (phase, next step) BEFORE announcing the next phase —
   resume trusts the gate line.
4. **The BLUEPRINT gate carries commit authorization.** Say it:
   **"Approving this plan authorizes its task commits."** On yes:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh grant <slug>`. The guard hook
   blocks agent commits without it. A push is NEVER granted here — it needs
   its own live yes, then `guard.sh allow-push-once`.

## Failure routing

| What failed | Route |
|---|---|
| A FORGE task is BLOCKED, or its checks fail for an unknown reason | **ANNEAL** with the task report; then back to that task |
| FORGE's fix budget (`implementation.max_fix_cycles`) is spent | forge stops and shows both reviews; ask the user: ANNEAL (cause unclear), STRIKE (known fixes), or accept |
| GUILD NOT_READY | **STRIKE** with the guild report path (step 5) |
| TEMPER NOT READY — failing tests, cause unknown | **ANNEAL** with the failing suite's report |
| TEMPER NOT READY — findings with a known fix (e.g. QA findings) | **STRIKE** with the report path |
| After ANNEAL / STRIKE | re-run ONLY the unit that broke (one task, or one suite, then re-consolidate temper) — not the phase start |
| The user rejects the same gate twice | stop; ask what outcome they want. Do not loop the phase a third time on the same feedback |

Set STATE.md's Phase to STRIKE or ANNEAL while a fix lane runs; the active
job stays this job.

## Running two pipelines at once

Safe only with its own checkout AND its own state lane (STATE.md holds ONE
`Active job:` line, so two pipelines in one place overwrite each other):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh create <job-b> pipeline   # checkout + lane in one step
```

Run the second pipeline inside that checkout; its `.smithy-lane` marker
makes every smithy script there use the lane. Reads see the shared history;
writes stay apart. When job B lands: `lane.sh merge <job-b>-pipeline`.
The commit grant is NOT per lane: one grant file per project. At exit, each
pipeline revokes only a grant that names its own job (step 7).
Never run two pipelines in the SAME checkout — one working tree cannot hold
two jobs' task commits, and both need a clean `git status`.

## Context discipline

- After each gate on a large job, recommend `/clear` — STATE.md and the
  ledger carry everything; resume loses nothing.
- If your context grows mid-FORGE, say so and recommend clearing at the next
  task boundary.

## Done when

- [ ] every phase that ran has a `DONE` / `APPROVED` / `PASS` ledger line (cite them)
- [ ] every gate has a gate line, or `pause_between_phases=false` was shown
- [ ] forge's one review: both verdicts APPROVED, or the user decided
- [ ] guild PRODUCTION_READY, or the panel was off, or the user accepted deferrals (decisions.md)
- [ ] temper READY and the ship gate approved
- [ ] `guard.sh status` shows no grant for this job; STATE.md Phase IDLE

## Output

The job folder `<memory>/jobs/<slug>/` (spec, plan, briefs, reports) and the
ledger. Nothing is pushed.

`Next: /smithy:handover — save the session for the next one`

## Red flags

| Thought | Reality |
|---|---|
| "I'll do this phase inline, invoking is overhead" | Inline phase work floods your context — the failure this design prevents. Invoke the skill. |
| "I remember where we were, skip the ledger" | Memory dies at compaction. The ledger is one command. Read it. |
| "The user approved three gates, skip this one" | Silent skips break the record. Present it briefly instead. |
| "I'll keep a summary of the spec in my context" | It stays there forever. Paths + 5 lines, no more. |
| "TEMPER failed on a flake, rerun until green" | Rerun-until-green hides flakes. Route it through ANNEAL. |
| "Guild findings are small, send them to forge" | Findings go to STRIKE — no plan needed, still checked and reviewed. |
