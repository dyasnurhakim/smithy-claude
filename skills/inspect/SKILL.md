---
name: inspect
description: Two-verdict code review (spec compliance + code quality) of a diff against its brief, via the read-only code-reviewer agent. Use when asked to "inspect", "review this task", "review my changes", or automatically inside /smithy:forge.
---

# Inspect — Two-Verdict Review

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append inspect <slug> <unit> STARTED -`

## Determine scope

- **Pipeline mode** (called from forge): brief + base sha already exist —
  the review package was built by forge; skip to Dispatch.
- **Standalone mode**: ask the user what to review and against what base
  (default: merge-base with the default branch). Write an ad-hoc brief at
  `docs/smithy/jobs/adhoc-<date>/briefs/review-brief.md` capturing what the
  change is SUPPOSED to do (from the user's description — ask, don't infer
  silently). Then:
  `review-package.sh record-base` is NOT appropriate here (HEAD is the work);
  instead set the base explicitly in STATE.md or pass a package built with
  `git diff <base>..HEAD` semantics via
  `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh build <brief> <out>`
  after writing the base sha into STATE.md's `- Base sha:` line.

## Dispatch

1. Resolve routing: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh review`
2. Dispatch the `smithy:code-reviewer` agent (model from routing). Prompt =
   effort banner + paths only: review package, creed, report output path
   (`jobs/<slug>/reports/<unit>-review.md`) + this line verbatim:
   **"Do Not Trust the Report — the implementor's claims are unverified.
   Verify each one against the diff and by running read-only checks."**

## Present results

3. Read the review report. Present to the user (or return to forge):
   - Verdict 1 (spec compliance) and Verdict 2 (code quality)
   - Findings table: severity, confidence, file:line
   - Do NOT soften severities; do NOT drop low-confidence findings — label them.

4. **Route the findings:**
   - Pipeline mode: return verdicts to forge (it owns the fix loop).
   - Standalone: if `gates.auto_fix_review_findings` is true in config,
     offer to dispatch fixes for Critical/High via a forge-style implementor
     brief; otherwise list findings with recommended actions and stop —
     the user decides.

5. **Log:** `ledger.sh append inspect <slug> <unit> <APPROVED|REJECTED> <review-report-path>`

## Rules

- The reviewer is read-only by design; never ask it to fix anything.
- Verdicts bind to the brief, not to taste: a design disagreement with the
  approved plan is a note, not a REJECTED.
- REJECTED (quality) requires at least one Critical or High finding.

Handoff: "REJECTED → fix loop in `/smithy:forge`; failures while fixing → `/smithy:anneal`."
