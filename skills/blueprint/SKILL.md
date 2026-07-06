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

## Checklist (create a todo per item)

1. Verify spec exists with zero open questions
2. Decompose into ≤8 verify-annotated tasks
3. Write plan.md; write one self-contained brief per task
4. Record base sha
5. Log decisions + rejected alternatives; update STATE.md; hand off

## Preconditions

`docs/smithy/jobs/<slug>/spec.md` must exist with an empty "Open questions"
section. If missing, offer to run `/smithy:assay` first — do not plan from a
verbal description. If open questions remain, resolve them (with the user)
before planning. The plan may not contain anything the spec doesn't cover;
discovering a needed decision here means going back to assay's question
process, not deciding silently.

## Decomposition rules

- **≤8 tasks**, each independently implementable and reviewable, ordered by
  dependency. More than 8 → the job wants splitting into two plans.
- **Thin vertical slices over layers**: "endpoint + validation + test for
  case A" beats "all models, then all handlers, then all tests". A slice
  proves the whole path early; layers defer integration risk to the end.
- **Verify-annotated, every step**: `N. [Step] → verify: [command/check]`.
  A task without a concrete verify command is not a task — rework it.
- **Testable requirements** (matters for TDD mode): phrase each requirement
  as observable behavior ("returns 404 when the id is unknown"), not
  implementation instructions ("add an if statement"). The jigsmith will
  bounce untestable requirements back here as NEEDS_CONTEXT.
- **Right-size tasks to one review**: a task whose diff a reviewer can't
  hold in one sitting (>~400 lines changed) is two tasks.

## Process

1. **Read spec.md.** Plan against it — nothing outside it enters the plan.

2. **Decompose** per the rules above. Consider at least one alternative
   decomposition and note in decisions.md why you rejected it.

3. **Write `docs/smithy/jobs/<slug>/plan.md`:**

   ```markdown
   # Plan — <title>
   Spec: jobs/<slug>/spec.md
   ## Tasks (dependency order)
   1. <task title> → verify: `<command>` — <expected>
   ## Success criteria (whole job)
   <the observable behaviors that mean "done" — temper tests against these>
   ## Rollback note
   <how to back out: branch/revert strategy>
   ```

4. **Write one brief per task** at `docs/smithy/jobs/<slug>/briefs/task-N.md`
   using EXACTLY the brief template from
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` — including the Report
   section's Status-line contract. Context files list ONLY what that task
   needs (the agent reads nothing else). Requirements are numbered and
   testable. The brief must be self-contained: an agent with ONLY that brief
   + the listed context files can complete the task without seeing the spec,
   the plan, or this conversation.

5. **Record the base.** Run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`
   (review packages are built from this sha — never HEAD~1).

6. **Log.** Design decisions + rejected alternatives → `docs/smithy/decisions.md`
   (≤3 lines each). Update STATE.md (phase BLUEPRINT, next step: forge task 1).
   `ledger.sh append blueprint <slug> plan DONE jobs/<slug>/plan.md`

## Red flags — these thoughts mean STOP

| Thought | Reality |
|---|---|
| "The brief can reference the spec for details" | Briefs are self-contained by contract. A brief that needs the spec leaks scope and context. Inline what the task needs. |
| "This step's verify is 'code review will catch it'" | Review is not a verify command. Every step needs a command or observable check the agent can run. |
| "Nine tasks is basically eight" | The cap forces scope honesty. Nine tasks = two plans or a fatter task honestly split. |
| "I'll decide this open design question in the plan" | Design decisions belong to assay's question process. Go back; don't decide silently. |
| "Layers are cleaner: models first, wiring later" | Layers defer the integration bugs to the last task, where they're most expensive. Slice vertically. |

## Exit criteria

- 100% of tasks have verify commands.
- Every brief passes the self-containment test.
- Base sha recorded in STATE.md.

Handoff: "Plan at `docs/smithy/jobs/<slug>/plan.md` (N tasks) — run `/smithy:forge` to implement."
