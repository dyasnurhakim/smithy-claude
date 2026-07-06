---
name: anneal
description: Systematic root-cause debugging — reproduce the failure, dispatch a read-only annealer for RCA, then apply the approved minimal fix with a regression test. Use when asked to "anneal", "debug this", "find the root cause", "why is this broken", or when tests fail unexpectedly in the pipeline.
---

# Anneal — Debug via Root Cause

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
If `docs/smithy/` is missing, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.
Job slug: the active job from STATE.md, or `adhoc-<YYYY-MM-DD>` for standalone use.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append anneal <slug> rca STARTED -`

**Iron law: RCA before fix. Always.** No fix is written, suggested-as-final,
or dispatched until a reproduced root cause exists. A fix without a root
cause is a guess wearing a fix's clothes.

## Checklist (create a todo per item)

1. Capture symptom + repro command; write the failure-context file
2. Dispatch the annealer (read-only RCA)
3. Handle RCA status; never proceed without ROOT_CAUSE_FOUND
4. Present root cause + fix; get the user's approval
5. Apply via jigsmith (regression test IS the RED); review
6. Original repro passes; regression test committed; decisions logged

## Process

1. **Collect the failure.** From the user or the failing report: symptom,
   exact repro command, expected vs actual. **No repro command → get one
   first** — ask the user or derive it from the failing test. "It sometimes
   breaks" is not a symptom; "this command produced this output at this
   time" is. Write `docs/smithy/jobs/<slug>/reports/rca-<n>-context.md`:

   ```markdown
   # Failure Context
   ## Symptom
   <one sentence, observable behavior>
   ## Repro command
   `<command>` → actual: <output> | expected: <output>
   ## Recent history
   <ledger tail 10; recent relevant commits — when did it last work?>
   ## Suspect files (if any — hypotheses, not conclusions)
   ```

2. **Dispatch the `smithy:annealer` agent.** Resolve routing:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh debugging`.
   Prompt = effort banner + paths only: context file, creed, report output
   path (`reports/rca-<n>.md`). The annealer is read-only; it will not fix.

3. **Handle the RCA status:**

   | Status | Your response |
   |---|---|
   | ROOT_CAUSE_FOUND | → step 4 |
   | CANNOT_REPRODUCE | Present the annealer's evidence (what it ran, what it saw). Ask the user for more signal: exact env, data, timing, versions. Never guess-fix an unreproduced bug — an unreproducible fix is unverifiable by definition. |
   | INCONCLUSIVE | Present the hypotheses ranked with their evidence. Ask which to pursue or what context the annealer lacked; consider one re-dispatch with `effort=max` and the new context. Two INCONCLUSIVEs → the user decides the next move. |

4. **Present root cause + recommended fix to the user**: the mechanism
   (file:line — what happens and why it produces the symptom), the minimal
   fix, the regression test. AskUserQuestion: apply the fix / revise / stop.
   Log the decision in `docs/smithy/decisions.md` (≤3 lines).

5. **Apply via the jigsmith — bug fixes are always TDD.** The regression
   test from the RCA IS the failing test: RED = the bug reproduced as a
   test, GREEN = the fix. Write a fix brief (`briefs/fix-<n>.md`,
   dispatch.md template + §4b TDD augmentation) whose requirements are the
   minimal fix EXACTLY as approved + the RCA's regression test. Verify
   commands: the original repro (now passing) + the project's test suite.
   Record base, dispatch `smithy:jigsmith` (routing role `implementation`),
   then review per `/smithy:inspect` — fix diffs get inspected like any
   other diff.

6. **Log.** `ledger.sh append anneal <slug> rca-<n> DONE reports/rca-<n>.md`
   plus the fix's forge/inspect lines. Update STATE.md.

## Red flags — these thoughts mean STOP

| Thought | Reality |
|---|---|
| "I can see the bug, skip the RCA" | What you can see is A cause. The annealer's job is proving it's THE cause — mechanism, not vibes. |
| "It's a one-line fix, the process is overkill" | One-line fixes without RCA are how the same bug returns wearing a different stack trace. |
| "Can't reproduce it, but the fix is probably right" | An unreproduced fix is unverifiable. CANNOT_REPRODUCE routes to the user, not to a guess. |
| "The regression test can come later" | Later means never, and the next regression proves it. RED is the regression test — it comes FIRST. |
| "Two bugs look related, I'll fix both" | One symptom, one RCA, one fix. Note the second bug; don't widen the diff. |
| "The annealer was INCONCLUSIVE, I'll just pick hypothesis 1" | Inconclusive means the evidence doesn't decide it. Get more evidence or ask — don't outvote the evidence. |

## Exit criteria

The original repro command passes, the regression test is committed and
passing (RED→GREEN evidence in the fix report), and the fix decision is in
decisions.md.

Handoff: "Return to the phase that broke (`/smithy:forge` task loop or the
failing `/smithy:temper` suite)."
