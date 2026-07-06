---
name: forge
description: Execute an approved smithy plan by dispatching the implementor agent per task brief, with a code review after each task. Use when asked to "forge", "implement the plan", "execute the blueprint", or after /smithy:blueprint.
---

# Forge — Implementation Loop

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` (the dispatch protocol is
binding: file handoffs, effort banners, status vocabulary, defensive parsing).
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append forge <slug> loop STARTED -`

## Preconditions

- `docs/smithy/jobs/<slug>/plan.md` + briefs exist. STATE.md has a base sha.
- Working tree is clean (each task commits atomically). If dirty, ask the user.

## Resume rule

Read the ledger first: `ledger.sh tail 30`. Start at the FIRST task with no
`DONE`+`APPROVED` pair. Never re-dispatch completed tasks. Trust the ledger
and `git log` over recollection.

## Per-task loop

1. **Resolve routing:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh implementation`

2. **Record base for this task:**
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`

3. **Dispatch the `implementor` agent** (Agent tool, agent type
   `smithy:implementor`, `model` from routing unless `inherit`). Prompt =
   effort banner + paths only: brief, creed, report output path, one line
   "Job <slug>, task N". Never paste file contents.

4. **Handle the status** (defensive rule from dispatch.md applies):
   - DONE → step 5.
   - DONE_WITH_CONCERNS → read report, triage each concern; proceed only if none blocks.
   - NEEDS_CONTEXT → answer from spec/plan if derivable, else ask the user; re-dispatch. Same question twice → user.
   - BLOCKED → resolve or escalate; consider one model-tier bump on retry.
   Log every resolution: `ledger.sh append forge <slug> task-N <STATUS> <report>`

5. **Review the task.** Build the package (paths from the project root):
   `review-package.sh build docs/smithy/jobs/<slug>/briefs/task-N.md docs/smithy/jobs/<slug>/reports/task-N-pkg.md docs/smithy/jobs/<slug>/reports/task-N-impl.md`
   Then dispatch `smithy:code-reviewer` per `/smithy:inspect`'s dispatch step
   (routing role `review`; prompt includes the Do-Not-Trust-the-Report line).

6. **Handle verdicts:**
   - Both APPROVED → `ledger.sh append inspect <slug> task-N APPROVED <review-report>`; update STATE.md; next task.
   - Any REJECTED → re-dispatch implementor with the review report path added
     to the brief context. Max 2 fix cycles, then STOP and escalate to the
     user with both report paths.

## Exit criteria

All tasks have DONE + APPROVED ledger lines.
Update STATE.md (phase FORGE complete, next step: temper).

Handoff: "All N tasks forged and approved — run `/smithy:temper` for the test pass."
