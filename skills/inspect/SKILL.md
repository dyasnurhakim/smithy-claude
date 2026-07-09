---
name: inspect
description: "Two-verdict code review (spec compliance + quality); findings need evidence, severity rationale, confidence. Triggers: 'inspect', 'review this change'."
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
2. Dispatch the `smithy:inspector` agent (model from routing). Prompt =
   effort banner + paths only: review package, creed, report output path
   (`jobs/<slug>/reports/<unit>-review.md`) + this line verbatim:
   **"Do Not Trust the Report — the forger's claims are unverified.
   Verify each one against the diff and by running read-only checks."**

## Present results

3. Read the review report. Present to the user (or return to forge):
   - Verdict 1 (spec compliance) and Verdict 2 (code quality)
   - Findings table: severity, confidence, file:line
   - Do NOT soften severities; do NOT drop low-confidence findings — label them.

4. **Route the findings:**
   - Pipeline mode: return verdicts to forge (it owns the fix loop).
   - Standalone: if `gates.auto_fix_review_findings` is true in config,
     offer to dispatch fixes for Critical/High via a forge-style forger
     brief; otherwise list findings with recommended actions and stop —
     the user decides.

5. **Log:** `ledger.sh append inspect <slug> <unit> <APPROVED|REJECTED> <review-report-path>`

## Rules

- The reviewer is read-only by design; never ask it to fix anything.
- Verdicts bind to the brief, not to taste: a design disagreement with the
  approved plan is a note, not a REJECTED.
- REJECTED (quality) requires at least one Critical or High finding.
- TDD-mode diffs (jigsmith): the inspector additionally verifies RED→GREEN
  commit ordering per requirement from the package's commit list — a `feat:`
  commit with no preceding `test:` commit for its requirement is a High
  finding (process evidence missing), whatever the code looks like.

## Evaluating the findings you receive

You are the controller; the inspector's report is input, not verdict-by-fiat.
Before acting on findings:
- Verify "every"/"all"/"no" generalizations against the diff before repeating
  them to the user — reviewers overgeneralize.
- Reclassify severity when the finding's own text undercuts its label
  (a "works fine but could be cleaner" is not High).
- A finding below confidence 7 is a question for investigation, not a fix
  order. Investigate or ask; don't blindly apply.
- Push back with evidence when a finding's premise is wrong — and record the
  pushback in the review report's margin (append a `## Controller notes`
  section) so the audit trail shows why a finding wasn't acted on.

## Red flags — these thoughts mean STOP

| Thought | Reality |
|---|---|
| "The findings look reasonable, apply them all" | Findings get verified, not obeyed. A wrong fix from a wrong finding is your diff now. |
| "It's REJECTED but the fixes are trivial, I'll just do them inline" | Fixes route through the fix loop (forge/jig) with their own review. Inline fixes skip the trail. |
| "Low-confidence findings clutter the report, drop them" | Label them, don't drop them — the user decides what noise is. |
| "The forger's report matches the diff, skip the checks" | The planted-violation test caught a fabricated verification. Run the read-only checks. |

Handoff: "REJECTED → fix loop in `/smithy:forge`; failures while fixing → `/smithy:anneal`."
