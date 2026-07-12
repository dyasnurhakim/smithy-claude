---
name: blueprint
description: "Spec → verify-annotated plan + self-contained task briefs, persona pass, parallel batch markers. Triggers: 'blueprint', 'plan this', 'break into tasks'."
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
3. Persona pass on the plan (2–4 relevant personas, inline)
4. Mark parallel batches (disjointness proven, evidence in plan)
5. Write plan.md; write one self-contained brief per task
6. Record base sha
7. Log decisions + rejected alternatives; update STATE.md; hand off

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

3. **Persona pass — review the PLAN before it hardens.** Two depths; the
   deep path runs in ISOLATED agent contexts, so its thinking never bloats
   this session.

   **3a. Inline pass (always).** Pick 2–4 personas relevant to the job type
   from `${CLAUDE_PLUGIN_ROOT}/references/personas/` (security for anything
   with auth/input/data; sre for services/config; qa always; designer +
   end-user for UI; support for error-heavy features; plus project personas
   from `docs/smithy/personas/`). Read each file and produce a STRUCTURED
   assessment — per persona × per task, not vague vibes:

   | Persona | Task | Finding | Type | Proposed change |

   (Type: missing-task, untestable-requirement, risk-needs-task,
   scope-question, sequencing) — plus a "whole-plan" row per persona for
   gaps no task covers (rollback? rate limiting the spec implied? empty
   states? migration path?).

   **3b. Deep pass (dispatched — offer it for high-stakes plans).** When
   the job touches auth/payments/data-migration/public UI, or the user
   asks: dispatch 1–3 personas as PARALLEL `smithy:inspector` overlays
   (routing role `review`, effort high) whose package is the PLAN + SPEC
   paths themselves — a plan review, not a code review. Their verdict
   format: per-task risk table + missing-task recommendations + the
   single-biggest-threat narrative. Fresh contexts think deeper than an
   inline skim, cost nothing in this session's context, and their reports
   land in `reports/plan-review-<persona>.md`. Note the cost (N review-
   routed agents) when offering.

   Every recommendation from either pass is surfaced at the plan gate as
   accept / reject-with-reason — recommendations improve the plan, they
   don't silently grow it. Accepted ones become plan changes BEFORE briefs
   are written.

4. **Mark parallel batches — prove disjointness first.** Two or more tasks
   may share a `∥ batch` marker ONLY when ALL of these hold (verify each,
   don't eyeball):
   - No file overlap: the union of each task's context files AND the files
     its requirements will touch is disjoint from every other task in the
     batch (list the file sets in the plan as evidence).
   - No data/ordering dependency: neither task consumes the other's output,
     schema, or exported symbols.
   - No shared scaffolding: they don't both "create the helper if missing".
   Default is SEQUENTIAL — an unmarked task never runs in parallel. A batch
   is at most 4 tasks (dispatch/review overhead grows per task). When in
   doubt, don't mark it: a false parallel marker costs a merge conflict and
   a batch restart; a false sequential marker costs only time.

5. **Write `docs/smithy/jobs/<slug>/plan.md`:**

   ```markdown
   # Plan — <title>
   Spec: jobs/<slug>/spec.md
   ## Tasks (dependency order; ∥ batch-X = may run in parallel)
   1. <task title> → verify: `<command>` — <expected>
   2. ∥ batch-A <task title> → verify: `<command>` — <expected>
   3. ∥ batch-A <task title> → verify: `<command>` — <expected>
   ## Parallel evidence (per batch)
   batch-A: task-2 files {src/a.ts, src/a.test.ts} ∩ task-3 files {src/b.ts, src/b.test.ts} = ∅; no cross-imports
   ## Success criteria (whole job)
   <the observable behaviors that mean "done" — temper tests against these>
   ## Rollback note
   <how to back out: branch/revert strategy>
   ```

6. **Write one brief per task** at `docs/smithy/jobs/<slug>/briefs/task-N.md`
   using EXACTLY the brief template from
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` — including the Report
   section's Status-line contract. Context files list ONLY what that task
   needs (the agent reads nothing else). **UI tasks: if
   `docs/smithy/DESIGN.md` exists, it goes in the context files** (the
   design source of truth from `/smithy:pattern`); if it doesn't and the
   job is UI-heavy, recommend running `/smithy:pattern` before forging. Requirements are numbered and
   testable. **Tag each brief's `## Persona` section** per the mapping in
   `${CLAUDE_PLUGIN_ROOT}/references/persona-modes.md`: masters/engineer.md
   always, + at most ONE domain specialist (security for auth/input/data,
   uiux or designer for UI, sre for service/config/infra).
   The brief must be self-contained: an agent with ONLY that brief
   + the listed context files can complete the task without seeing the spec,
   the plan, or this conversation.

7. **Record the base.** Run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`
   (review packages are built from this sha — never HEAD~1).

8. **Log.** Design decisions + rejected alternatives → `docs/smithy/decisions.md`
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
