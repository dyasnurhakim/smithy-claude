---
name: blueprint
description: Turn a spec into a verify-annotated implementation plan and per-task briefs. Use when asked to "blueprint", "plan this feature", "break this into tasks", or after /smithy:assay produced a spec.
---

# Blueprint — Plan & Briefs

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append blueprint <slug> plan STARTED -`

Resolve your own effort: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh planning`
— apply that effort to the decomposition thinking in this skill.

## Preconditions

`docs/smithy/jobs/<slug>/spec.md` must exist with an empty "Open questions"
section. If missing, offer to run `/smithy:assay` first — do not plan from a
verbal description. If open questions remain, resolve them (with the user)
before planning.

## Process

1. **Read spec.md.** Plan against it — nothing outside it enters the plan.

2. **Decompose into tasks.** ≤8 tasks, each independently implementable and
   reviewable, ordered by dependency. Prefer thin vertical slices over layers.
   Every task step is verify-annotated: `N. [Step] → verify: [command/check]`.
   A task without a concrete verify command is not a task — rework it.

3. **Write `docs/smithy/jobs/<slug>/plan.md`:**

   ```markdown
   # Plan — <title>
   Spec: jobs/<slug>/spec.md
   ## Tasks (dependency order)
   1. <task title> → verify: `<command>` — <expected>
   ## Success criteria (whole job)
   ## Rollback note
   <how to back out: branch/revert strategy>
   ```

4. **Write one brief per task** at `docs/smithy/jobs/<slug>/briefs/task-N.md`
   using EXACTLY the brief template from
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` — including the Report
   section's Status-line contract. Context files list ONLY what that task
   needs. Requirements are numbered and testable.

5. **Record the base.** Run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`
   (review packages are built from this sha — never HEAD~1).

6. **Log.** Design decisions + rejected alternatives → `docs/smithy/decisions.md`
   (≤3 lines each). Update STATE.md (phase BLUEPRINT, next step: forge task 1).
   `ledger.sh append blueprint <slug> plan DONE jobs/<slug>/plan.md`

## Exit criteria

- 100% of tasks have verify commands.
- Every brief is self-contained: an agent with ONLY that brief + the listed
  context files can complete the task.

Handoff: "Plan at `docs/smithy/jobs/<slug>/plan.md` (N tasks) — run `/smithy:forge` to implement."
