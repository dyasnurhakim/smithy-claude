---
name: forge
description: "Build the plan task by task with forger or jigsmith agents (each self-checks and makes one commit), then ONE review of the whole job. Parallel batches in worktrees. Works without a plan for a single task. Triggers: 'forge', 'implement the plan', 'build this'."
---

# Forge — Build the Plan

```
plan ─▶ task 1 ─▶ task 2 ─▶ … ─▶ task N ─▶ ONE review (whole job) ─▶ fix rounds ─▶ report
         agent: build → check → self-check → 1 commit      inspector: BASE..HEAD
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh forge auto` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`. TDD tasks: also `/smithy:jig` (skills/jig/SKILL.md).

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| `jobs/<slug>/plan.md` + `briefs/task-N.md` | use them | **One task** (the request fits one brief): write that brief yourself (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3) plus a short `plan.md` (title, goal, one task line) so the final review has a brief; show them, and ask "build this?". **More than one task**: offer `/smithy:blueprint` — or, if the user says go, write a short plan with one brief per task and confirm it the same way |
| Plan approval | a gate line in the ledger, or the user said yes | ask; the yes covers this plan only |
| Commit approval | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh status` shows a grant | on the plan yes: `guard.sh grant <slug>` |
| Job base sha | STATE.md `Base sha` for this job | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base` (once, now) |
| Clean working tree | continue | show `git status --short`, ask; never stash on your own |

## Steps

1. **Resume check** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail 30` and
   `git log --oneline <base>..HEAD`. Start at the first task with no `DONE`
   line. Never redo a finished task.
   → verify: you can name the first task to run, with the ledger line that proves the earlier ones.

2. **Choose the builder** (once per job) —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get implementation.tdd`:
   `always` → jigsmith; `never` → forger; `ask` → ask the user once, with a
   recommendation from `/smithy:jig` § When to use TDD (mixed plans may
   route per task — say which and why). TDD in play → read the three TDD
   settings in one call (jig § The three settings) and say them in one line.
   If `tdd_commits` printed an old-name note, handle it as jig Step 1 says:
   tell the user once what the old value now means (ONE commit per task),
   and ask before the first commit (they may want `stages`, or to stop).
   Log the choice in `decisions.md` (≤3 lines).
   → verify: each task has a builder; the settings line was shown.

3. **Lookup** (creed §10, once per job, before the first dispatch) — memory:
   past decisions and bugs on the plan's files; graph: callers of the code
   that will change. Add what matters to each brief's `key_facts`.
   → verify: `key_facts` filled with sources, or `[]`.

4. **Per task** —
   a. TDD task: add jig's brief lines (jig § Brief lines).
   b. Dispatch per `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §1–2 (role `implementation`;
      prompt = banner + paths + "Job <slug>, task N").
   c. Handle the status (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §4). Never answer
      NEEDS_CONTEXT with a guess — use spec/plan, or ask.
   d. TDD task: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tdd-snap.sh verify <slug> task-N`
      must print `OK` (a FAIL → re-dispatch once with the FAIL line; again → the user).
      Parallel tasks: run it inside the task's worktree (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §7).
   e. Check the one commit: `git log --oneline -1` matches the brief's message.
   f. `ledger.sh append forge <slug> task-N <STATUS> <report>`; update STATE.md.
   → verify: DONE line in the ledger; TDD tasks have `tdd-verify: OK`.

5. **Parallel batches** — only tasks marked `∥ batch-X` in the plan, and only
   if the user says yes for that batch. Follow `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §7
   exactly (integration branch, one worktree per task, all dispatches in ONE
   message, test in integration, land, merge lanes, clean up).
   → verify: `worktree.sh list` shows no smithy worktrees; `lane.sh list` shows no open lanes.

6. **Final review — once, after ALL tasks** — follow `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §5:
   one package from the job base to HEAD with `plan.md` as the brief and the
   reports folder `jobs/<slug>/reports/` as the third argument, ONE
   `inspector`. Name the TDD commits mode in the prompt if TDD ran. Judge the
   findings before acting (`/smithy:inspect` § Judging findings).
   → verify: a review report exists with two verdicts.

7. **Fix rounds** — REJECTED → `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §6: re-dispatch the
   builder for the affected tasks with the review path in their briefs, then
   review only the fix diff. Budget: `implementation.max_fix_cycles` rounds
   (`config.sh get implementation.max_fix_cycles`). Spent → stop and show the
   user both reviews and why you think it is stuck.
   → verify: both verdicts APPROVED, or the user decided.

8. **Report** — write `jobs/<slug>/reports/forge-report.md` (below), then delete
   the per-task scratch (`reports/task-*-impl.md`, `reports/review-pkg*.md`;
   keep `reports/raw/` and the review report). Log
   `ledger.sh append forge <slug> report DONE jobs/<slug>/reports/forge-report.md`.
   Update STATE.md (phase FORGE done, next: temper).
   → verify: one forge-report.md; no `task-*-impl.md` left.

### forge-report.md

Envelope (`kind: forge-report`, `unit: all`, `agent: controller`, `status:
DONE`; carry forward every open `key_facts`/`concerns` from all reports),
then:

```markdown
# Forge Report — <job>
## Summary
<N tasks, N commits, batches run, fix rounds used — five lines at most>
| Task | Status | Builder | Commit | TDD proof |
|------|--------|---------|--------|-----------|
| task-1 | DONE | jigsmith | a1b2c3 feat: … | tdd-verify OK |
## Review
<verdicts, findings fixed, findings declined and why>
## Per-task notes (only what the next phase needs)
## Open concerns (copied from the task envelopes)
```

## Done when

- [ ] every task has a DONE ledger line (cite them)
- [ ] TDD tasks: `tdd-verify: OK` for each (paste the lines)
- [ ] one commit per task (`git log --oneline <base>..HEAD` matches the task count, plus fix commits)
- [ ] one final review, both verdicts APPROVED — or the user decided after the fix budget ran out
- [ ] no smithy worktrees and no open lanes remain
- [ ] `forge-report.md` written; per-task scratch deleted; STATE.md updated

## Output

`jobs/<slug>/reports/forge-report.md` · the review report · `reports/raw/` (TDD logs).

`Next: /smithy:guild — production panel (when review_panel is on), else /smithy:temper`

## Red flags

| Thought | Reality |
|---|---|
| "The task is tiny, I'll just do it myself" | Doing it inline skips the brief, the self-check and the record. Dispatch it. |
| "DONE, so skip the TDD verify" | DONE is a claim. `tdd-snap verify` is the proof. Run it. |
| "One more fix round will do it" | `max_fix_cycles` is the budget. The next round is the user's call. |
| "These two tasks look separate, run them in parallel" | Only blueprint's `∥` marker plus the user's yes allow that. |
| "The batch landed; merge lanes later" | Later is after compaction, when nobody knows which lanes existed. Now. |
| "The tree is only a little dirty" | Dirt ends up in a task commit and in the review diff. Clean it or ask. |
