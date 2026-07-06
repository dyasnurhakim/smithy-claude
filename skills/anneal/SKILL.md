---
name: anneal
description: Systematic root-cause debugging — reproduce the failure, dispatch a read-only debugger for RCA, then apply the approved minimal fix with a regression test. Use when asked to "anneal", "debug this", "find the root cause", "why is this broken", or when tests fail unexpectedly in the pipeline.
---

# Anneal — Debug via Root Cause

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
If `docs/smithy/` is missing, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.
Job slug: the active job from STATE.md, or `adhoc-<YYYY-MM-DD>` for standalone use.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append anneal <slug> rca STARTED -`

**Iron law: RCA before fix. Always.** No fix is written, suggested-as-final,
or dispatched until a reproduced root cause exists.

## Process

1. **Collect the failure.** From the user or the failing report: symptom,
   exact repro command, expected vs actual. If there is no repro command,
   get one first — ask the user or derive it from the failing test. Write
   the failure-context file `docs/smithy/jobs/<slug>/reports/rca-<n>-context.md`:

   ```markdown
   # Failure Context
   ## Symptom
   ## Repro command
   `<command>` → actual: <output> | expected: <output>
   ## Recent history
   <ledger tail 10; recent relevant commits>
   ## Suspect files (if any — hypotheses, not conclusions)
   ```

2. **Dispatch the `smithy:debugger` agent.** Resolve routing:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh debugging`.
   Prompt = effort banner + paths only: context file, creed, report output
   path (`reports/rca-<n>.md`). The debugger is read-only; it will not fix.

3. **Handle the RCA status:**
   - ROOT_CAUSE_FOUND → step 4.
   - CANNOT_REPRODUCE → present the debugger's evidence to the user; ask for
     more signal (exact env, data, timing). Never guess-fix an unreproduced bug.
   - INCONCLUSIVE → present hypotheses ranked with evidence; ask the user
     which to pursue or what extra context exists; consider re-dispatch with
     effort=max.

4. **Present root cause + recommended fix to the user** (mechanism, file:line,
   the minimal fix, the regression test). AskUserQuestion: apply the fix /
   revise / stop. Log the decision in `docs/smithy/decisions.md`.

5. **Apply via implementor.** Write a fix brief
   (`briefs/fix-<n>.md`, dispatch.md template) whose requirements are:
   the minimal fix EXACTLY as approved + the regression test from the RCA.
   Verify commands: the original repro (now passing) + the project's test
   suite. Record base, dispatch `smithy:implementor` (routing role
   `implementation`), review per `/smithy:inspect` if the fix touches more
   than the RCA named.

6. **Log.** `ledger.sh append anneal <slug> rca-<n> DONE reports/rca-<n>.md`
   and the fix's forge/inspect lines. Update STATE.md.

## Exit criteria

The original repro command passes, the regression test is committed and
passing, and the fix decision is in decisions.md.

Handoff: "Return to the phase that broke (`/smithy:forge` task loop or `/smithy:temper` rerun)."
