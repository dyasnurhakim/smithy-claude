---
name: blueprint
description: "Spec → plan: ≤8 tasks, each with a verify check, a persona pass, parallel batch markers with proof, and one self-contained brief per task. Works from a verbal request too (writes a mini spec). Triggers: 'blueprint', 'plan this', 'break into tasks'."
---

# Blueprint — Plan and Briefs

```
spec.md ─▶ tasks (≤8, thin slices, each → verify) ─▶ persona pass ─▶ ∥ batches (proven)
   (no spec? ≤5 questions ─▶ mini spec)
        ─▶ plan.md + briefs/task-N.md ─▶ record the job base (once) ─▶ plan gate
                                                                   (yes = commit grant)
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh blueprint auto` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`, `${CLAUDE_PLUGIN_ROOT}/references/persona-modes.md`.
3. Effort: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh planning` — plan at that effort.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| `jobs/<slug>/spec.md` | plan against it | ask ≤5 questions (goal, in/out of scope, key behaviors, constraints, what "done" means). Write a mini spec at `jobs/<slug>/spec.md` in assay's template (`${CLAUDE_PLUGIN_ROOT}/skills/assay/SKILL.md` step 5), show it, continue on the user's OK. Too big for 5 questions → recommend `/smithy:assay` |
| Empty "Open questions" in the spec | continue | resolve each one with the user first; record it under Resolved questions |
| The job base sha | STATE.md `Base sha` for THIS job | step 8 records it |
| `<memory>/DESIGN.md` (UI jobs) | add it to UI tasks' context files | UI-heavy job: recommend `/smithy:pattern` before forge; do not stop |
| Project personas (`<memory>/personas/`) | add them to the persona pass | use the plugin's personas only |

## Steps

1. **Read the spec.** Plan only what it covers. A decision the spec does
   not make → ask the user (assay's question method) and add it to the
   spec's Resolved questions. Never decide it silently in the plan.
   → verify: every task traces to a line of the spec.

2. **Break into tasks** — the rules:
   - **≤8 tasks**, each built and checked on its own, in dependency order.
     More than 8 → split the job into two plans.
   - **Thin vertical slices, not layers.** "endpoint + validation + test
     for case A" beats "all models, then all handlers, then all tests".
     A slice proves the whole path early; layers push integration bugs to
     the last task.
   - **Every task has a check:** `N. <step> → verify: <command or check>`.
     No concrete check → it is not a task yet; rework it.
   - **Requirements are observable behavior** ("returns 404 when the id is
     unknown"), never code orders ("add an if"). This makes them TDD-ready
     (`/smithy:jig`, skills/jig/SKILL.md § When to use TDD); the jigsmith
     sends untestable ones back as NEEDS_CONTEXT.
   - **One agent can hold it:** a task over ~400 changed lines is two tasks.

   Sketch at least one other way to split the job; note in
   `decisions.md` why you did not pick it.
   → verify: ≤8 tasks; each has a `→ verify:`; each requirement is observable.

3. **Persona pass — review the plan before it hardens.**
   - **Inline (always).** Pick 2–4 personas for this job from
     `${CLAUDE_PLUGIN_ROOT}/references/personas/` (security for auth/input/data; sre for
     services/config; qa always; designer + end-user for UI; support for
     error-heavy features) plus project personas. Read each one and fill a
     table per persona × task, plus one "whole plan" row per persona for
     gaps no task covers (rollback? rate limits the spec implied? empty
     states? migration path?):

     | Persona | Task | Finding | Type | Proposed change |
     |---|---|---|---|---|

     Type = missing-task · untestable-requirement · risk-needs-task ·
     scope-question · sequencing.
   - **Deep (offer it for high-stakes plans** — auth, payments, data
     migration, public UI — or when the user asks). Dispatch 1–3 personas as
     PARALLEL `inspector` overlays (role `review`, `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
     §1–2) whose package is the plan + spec paths: a plan review, not a code
     review. Ask for a per-task risk table, missing tasks, and the single
     biggest threat. Reports go to `reports/plan-review-<persona>.md`. Say
     the cost (N review agents) when you offer.

   Every recommendation goes to the plan gate as accept / reject-with-reason.
   Accepted ones change the plan BEFORE briefs are written.
   → verify: every recommendation is listed with accept/reject and a reason.

4. **Mark parallel batches — prove they are separate.** Tasks may share a
   `∥ batch-X` marker ONLY when all of these hold (check each, do not eyeball):
   - **No file overlap:** the files each task reads or changes do not
     overlap with any other task in the batch. Write the file sets in the
     plan as proof.
   - **No order or data link:** neither task uses the other's output,
     schema or exported names.
   - **No shared scaffolding:** they do not both "create the helper if missing".

   Default is one after another: an unmarked task never runs in parallel.
   At most 4 tasks per batch. In doubt, do not mark: a wrong parallel marker
   costs a merge conflict and a batch restart; a wrong sequential one costs
   only time.
   → verify: every batch has a Parallel evidence line with `∩ = ∅`.

5. **Write** `<memory>/jobs/<slug>/plan.md`:

   ```markdown
   # Plan — <title>
   Spec: jobs/<slug>/spec.md
   ## Tasks (dependency order; ∥ batch-X = may run in parallel)
   1. <task title> → verify: `<command>` — <expected>
   2. ∥ batch-A <task title> → verify: `<command>` — <expected>
   3. ∥ batch-A <task title> → verify: `<command>` — <expected>
   ## Parallel evidence (per batch)
   batch-A: task-2 {src/a.ts, src/a.test.ts} ∩ task-3 {src/b.ts, src/b.test.ts} = ∅; no cross-imports
   ## Success criteria (whole job)
   <observable behaviors that mean "done" — temper tests against these>
   ## Rollback note
   <how to back out: branch / revert plan>
   ```
   → verify: the file exists and every task line has `→ verify:`.

6. **Lookup** (creed §10, ONE, per `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3) on the
   plan's files and topic — memory: past decisions and bugs on these files;
   graph: callers of the code that will change. None installed → say so.
   → verify: you have the facts (with sources) to put in `key_facts`, or `[]`.

7. **Write one brief per task** at `<memory>/jobs/<slug>/briefs/task-N.md`,
   exactly in the template of `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3 (envelope first;
   `key_facts` from step 6 with sources).
   - Context files: ONLY what this task needs — the agent reads nothing else.
     UI task + DESIGN.md exists → DESIGN.md is a context file.
   - Requirements: numbered, observable behavior (step 2).
   - `## Persona`: per `${CLAUDE_PLUGIN_ROOT}/references/persona-modes.md` —
     `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/engineer.md` always, plus at most ONE
     specialist (security for auth/input/data, uiux or designer for UI,
     sre for service/config/infra).
   - Self-contained: an agent with ONLY this brief and its context files
     can finish the task without the spec, the plan or this chat.
   → verify: one brief per task; each passes the self-contained test.

8. **Record the job base — once.** If STATE.md's active job is this job and
   `Base sha` is already set, keep it (re-planning must not cut earlier
   commits out of the final review). Otherwise:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`
   (the final review diffs from this sha — never HEAD~1).
   → verify: `base=<sha>` printed, or the kept base is named.

9. **Plan gate.** In a pipeline, the orchestrator runs it. On its own: show
   the plan path, a ≤5-line summary and the persona recommendations, and say
   **"Approving this plan authorizes its task commits."** On yes:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh grant <slug>` and
   `ledger.sh append gate <slug> blueprint APPROVED jobs/<slug>/plan.md`.
   → verify: `guard.sh status` shows the grant, or the orchestrator has the plan path.

10. **Log** — decisions and rejected options → `decisions.md` (≤3 lines
    each). STATE.md: `- Active job: jobs/<slug>/` (so `start.sh forge auto`
    continues this job), Phase BLUEPRINT, the `Base sha` from step 8 kept
    as is, next step `/smithy:forge` task 1.
    `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append blueprint <slug> plan DONE jobs/<slug>/plan.md`
    → verify: `ledger.sh tail 1` shows the DONE line.

## Done when

- [ ] a spec exists (full, or a mini spec the user OK'd) with no open questions
- [ ] ≤8 tasks, every one with a `→ verify:` check
- [ ] every requirement is observable behavior
- [ ] persona recommendations listed with accept/reject and a reason
- [ ] every `∥` batch has file-set proof in Parallel evidence
- [ ] one self-contained brief per task, with `key_facts` and `## Persona`
- [ ] the job base is in STATE.md (recorded once)
- [ ] plan approved + commit grant (standalone), or handed to the pipeline gate
- [ ] decisions.md, STATE.md and the ledger DONE line written

## Output

`<memory>/jobs/<slug>/plan.md` · `briefs/task-N.md` · `spec.md` (if you wrote
the mini spec) · `reports/plan-review-<persona>.md` (deep pass only).

`Next: /smithy:forge — build the plan, task by task`

## Red flags

| Thought | Reality |
|---|---|
| "The brief can point to the spec for details" | Briefs are self-contained. A brief that needs the spec leaks scope. Put what the task needs in it. |
| "This step's check is 'the review will catch it'" | A review is not a check. Every step needs a command or an observable check the agent can run. |
| "Nine tasks is basically eight" | The cap keeps scope honest. Nine tasks = two plans. |
| "I'll settle this open design question in the plan" | Design decisions are the user's. Ask; do not decide silently. |
| "Layers are cleaner: models first, wiring later" | Layers push integration bugs to the last, most expensive task. Slice vertically. |
| "No spec, so I can't plan" | Ask ≤5 questions, write the mini spec, keep going. |
