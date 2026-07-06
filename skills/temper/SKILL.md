---
name: temper
description: Full test pass — runs ring-test (unit), wield (QA), proof (stress), and hone (perf) in sequence and produces one consolidated READY / NOT READY verdict. Use when asked to "temper", "test everything", "full test pass", or after /smithy:forge completes.
---

# Temper — Testing Umbrella

(Tempering = controlled stress until the metal holds.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/stacks.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append temper <slug> suite STARTED -`

## Process

1. **Detect the stack:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh`.
   Show the result. If `stack=unknown` or it contradicts the repo, confirm
   with the user before proceeding.

2. **Select the suites.** Read `testing.skip` from the effective config
   (`routing.sh` handles routing only — read `docs/smithy/config.json`
   directly for `testing`, falling back to
   `${CLAUDE_PLUGIN_ROOT}/defaults/config.json`). Then AskUserQuestion
   (multiSelect) with the remaining suites, defaults pre-picked:
   - ring-test — always suggested
   - wield — always suggested
   - proof — suggested ONLY if a runnable service exists (spec/STATE/ask)
   - hone — suggested if the job touched hot paths or the user cares about perf
   Note skipped suites in the summary — a skipped suite is a gap, not a pass.

3. **Run the selected skills in order** ring-test → wield → proof → hone,
   each per its own SKILL.md (each writes its own report + ledger line).
   A FAIL does not abort the remaining suites (full information first) —
   EXCEPT: skip proof if wield found a Critical (don't load-test a broken app).

4. **Consolidate** into `docs/smithy/jobs/<slug>/reports/temper-summary.md`:

   ```markdown
   # Temper Summary — <job> — <date>
   Stack: <stack-detect line>
   | Suite | Status | Report | Headline |
   |-------|--------|--------|----------|
   | ring-test | PASS/FAIL/SKIPPED | reports/test-unit.md | <one line> |
   | wield     | ... + health score X/100 |
   | proof     | ... |
   | hone      | ... |
   ## Verdict: READY | NOT READY
   <READY requires: every non-skipped suite PASS. Anything else is NOT READY.>
   ## Gaps
   <skipped suites, uncovered criteria, deferred findings>
   ```

5. **Log + update.** `ledger.sh append temper <slug> suite <PASS|FAIL|PARTIAL> reports/temper-summary.md`
   (PARTIAL when a suite reported PARTIAL and nothing FAILed);
   update STATE.md (phase TEMPER done, next step).

## Rules

- Never soften the verdict: one failing non-skipped suite = NOT READY.
- Never rerun a suite to "get a better number" without a change in between.

Handoff: "NOT READY → `/smithy:anneal` with the failing report. READY → gate approval in `/smithy` or `/smithy:handover`."
