---
name: forge
description: Execute an approved smithy plan by dispatching the forger (or jigsmith, in TDD mode) per task brief, with a code review after every task. Use when asked to "forge", "implement the plan", "execute the blueprint", or after /smithy:blueprint.
---

# Forge — Implementation Loop

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` (the dispatch protocol is
binding: file handoffs, effort banners, status vocabulary, defensive parsing).
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append forge <slug> loop STARTED -`

## Checklist (create a todo per item)

1. Verify preconditions (plan, briefs, base sha, clean tree)
2. Read ledger; compute resume position
3. Choose implementation mode (TDD vs plain) per config
4. Per task: dispatch → handle status → review → verdict → log
5. All tasks DONE + APPROVED; STATE.md updated; hand off to temper

## Preconditions — check all four before any dispatch

- `docs/smithy/jobs/<slug>/plan.md` exists and every task has a brief in
  `briefs/`. Missing → offer `/smithy:blueprint`; never improvise briefs here.
- STATE.md has a base sha (blueprint records it).
- Working tree is clean (`git status --short`) — each task commits atomically.
  Dirty tree → show the user what's dirty and ask; never stash silently.
- The plan was approved (gate line in the ledger, or the user says so now).

## Resume rule

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail 30` first. Start at the
FIRST task lacking a `DONE`+`APPROVED` pair. Never re-dispatch completed
tasks. Cross-check `git log --oneline <base>..HEAD` — commits are ground
truth for what actually happened. **Trust the ledger and git log over your
recollection**, especially after compaction.

## Step 0 — choose the implementation mode (once per job)

Read `implementation.tdd` from `docs/smithy/config.json` (fall back to
`${CLAUDE_PLUGIN_ROOT}/defaults/config.json`):

- `"always"` → every task goes to the **jigsmith** (TDD; see `/smithy:jig`).
- `"never"` → every task goes to the plain **forger**.
- `"ask"` (default) → AskUserQuestion ONCE, at the first task, with a
  recommendation from the jig suitability table (`/smithy:jig`): TDD for
  behavior-specifiable work and all bug fixes; plain forge for exploratory/
  visual/mechanical work. Mixed plans may choose per-task — say which tasks
  you'd route where and why.

Record the choice in `docs/smithy/decisions.md` (≤3 lines).

## Per-task loop

1. **Resolve routing:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh implementation`
   → model + effort banner (dispatch.md table).

2. **Record base for this task:**
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`

3. **Dispatch** the `smithy:forger` — or `smithy:jigsmith` in TDD mode, after
   augmenting the brief per dispatch.md §4b. Agent tool with `model` from
   routing (omit if `inherit`). The prompt contains ONLY: the effort banner,
   absolute paths (brief, creed, report output), and one line "Job <slug>,
   task N". Never paste file contents — paths only.

4. **Handle the status** (defensive rule from dispatch.md applies to
   malformed reports):

   | Status | Your response |
   |---|---|
   | DONE | → step 5 |
   | DONE_WITH_CONCERNS | Read the report. Triage EVERY concern: blocking → resolve before review; non-blocking → carry into the review package notes. Never proceed with an untriaged concern. |
   | NEEDS_CONTEXT | Answer from spec.md/plan.md if derivable; else ask the user. Re-dispatch with the answer appended to the brief. Same question twice → the user decides. |
   | BLOCKED | Resolve the blocker if you can (env, missing file). Else escalate to the user. On retry after an agent-capability blocker, consider one model-tier bump (dispatch.md §6). |

   Log every resolution: `ledger.sh append forge <slug> task-N <STATUS> <report>`

5. **Review the task — never skip, never self-review.** Build the package
   (paths from the project root):
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh build docs/smithy/jobs/<slug>/briefs/task-N.md docs/smithy/jobs/<slug>/reports/task-N-pkg.md docs/smithy/jobs/<slug>/reports/task-N-impl.md`
   Then dispatch the `smithy:inspector` per `/smithy:inspect` (routing role
   `review`; the Do-Not-Trust-the-Report line goes in the prompt verbatim).
   In TDD mode the inspector also verifies RED→GREEN commit ordering.

6. **Handle the verdicts:**
   - Both APPROVED → `ledger.sh append inspect <slug> task-N APPROVED <review-report>`;
     update STATE.md (task N done, next task named); next task.
   - Any REJECTED → re-dispatch the implementation agent with the review
     report path added to the brief context. **Max 2 fix cycles per task**,
     then STOP: present both report paths to the user with your read on why
     it's stuck (bad brief? wrong approach? agent capability?).

## Red flags — these thoughts mean STOP

| Thought | Reality |
|---|---|
| "The task is tiny, I'll implement it inline myself" | Inline work skips the brief, the report, and the review. Dispatch it — that's the audit trail. |
| "The report says DONE, reviews are slowing us down" | The planted-violation test exists because DONE has been a lie before. Review every task. |
| "Two rejections — one more cycle will fix it" | Two cycles is the budget. The third is the user's call, not yours. |
| "The concern is minor, I'll note it later" | Untriaged concerns are how DONE_WITH_CONCERNS becomes silently DONE. Triage now. |
| "I'll answer NEEDS_CONTEXT with my best guess" | The agent refused to guess — don't guess on its behalf. Derive from spec/plan or ask. |
| "The tree is only a little dirty" | Any dirt contaminates the task's atomic commit and its review diff. Clean or ask. |

## Exit criteria

Every task has DONE + APPROVED ledger lines. Update STATE.md (phase FORGE
complete, next step: temper).

Handoff: "All N tasks forged and approved — run `/smithy:temper` for the test pass."
