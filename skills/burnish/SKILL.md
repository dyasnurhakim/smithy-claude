---
name: burnish
description: Review the current UI/UX against the design system (or sound heuristics) with screenshot evidence, then improve it — surgical fixes with before/after proof. Use when asked to "burnish", "review the design", "improve the UI/UX", "polish the look", "why does this look off", or after UI work lands.
---

# Burnish — Design Review & Improvement

(Burnishing polishes finished metal to a better surface — the piece exists;
you make it right.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Job slug: active job from STATE.md, or `burnish-<YYYY-MM-DD>` standalone.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append burnish <slug> audit STARTED -`

Requires a runnable UI target (run command + URL from spec/STATE.md, or
ask) and Playwright via npx. LOCAL targets only. No target → this skill
cannot run honestly; say so and stop.

## Checklist (create a todo per item)

1. Baseline capture (screenshots, key pages × breakpoints)
2. Evaluate against DESIGN.md (or declared heuristics) — proof per finding
3. Present findings + improvement plan; user approves (gate)
4. Fix loop: surgical fix → commit → after-screenshot → verify
5. Re-score, write report (md + json), route leftovers

## 1. Baseline capture

Evidence dir: `docs/smithy/jobs/<slug>/reports/burnish-evidence/`.
Screenshot every key page/state the user names (default: main pages plus
one form, one empty state, one error state) at 320 / 768 / 1440 widths:
`npx playwright screenshot --viewport-size=<w>,720 <url> <dir>/base-<page>-<w>.png`
(scratch spec for states needing interaction). These baselines are the
before-images for every later fix.

## 2. Evaluate — standard first, then eyes

**Standard:** `docs/smithy/DESIGN.md` if it exists (tokens, states, voice —
drift from it is a finding with the DESIGN.md line cited). No DESIGN.md →
evaluate against these declared heuristics AND say so in the report:
- Hierarchy: one clear primary action/message per view; scale contrast.
- Rhythm: consistent spacing scale; alignment to a grid; no orphan margins.
- Consistency: same radius/shadow/spacing/terminology for the same concept.
- States: hover/focus/active/disabled designed; loading/empty/error present.
- Accessibility: contrast (compute it), focus visibility, touch targets,
  keyboard reachability of primary flows.
- Anti-template: the banned list from `/smithy:pattern` — default-look UI,
  uniform card grids, gray+one-accent, undesigned states, and the three AI
  clichés (cream+serif+terracotta / near-black+acid accent / broadsheet
  hairlines) appearing as unexamined defaults.
- Distinctiveness: is there a signature element, or would this design fit
  any product? Copy check: end-user vocabulary, consistent action names,
  errors that direct rather than apologize.
- Responsive: no overflow/breakage at the three widths.

For the evaluation itself, adopt the `master-designer` persona
(`${CLAUDE_PLUGIN_ROOT}/references/personas/masters/designer.md`) alongside
the heuristics — or, on large apps, dispatch it as a `smithy:inspector`
overlay (routing role `review`) with the baseline screenshots as its live
evidence, and merge its findings into yours.

Every finding follows the inspector evidence contract: screenshot path +
what it shows (crop/annotate mentally — name the region in `detail`),
why flagged, severity + because (Critical = a user class blocked or data
lost; High = primary flow degraded / AA failure; Medium = consistency or
rhythm break; Low = polish). Fingerprint each finding for cross-run trends.

## 3. Gate — findings before fixes

Present: score (wield rubric, UX-weighted: Visual 25, UX 25, A11y 20,
Consistency 15, Responsive 15), findings table with evidence paths, and the
improvement plan (finding → intended change → risk). AskUserQuestion:
approve all / select subset / stop at report. **This skill never edits
without this gate.** Standalone fixes also need a commit grant
(`guard.sh status`; ask + `guard.sh grant <slug>` on yes).

## 4. Fix loop (approved findings, severity order)

Per finding: write a fix brief (dispatch.md template — context: the files +
the evidence screenshot + the DESIGN.md rule; requirement: the SMALLEST
change that resolves it; no drive-by refactors) → dispatch `smithy:forger`
(routing role `implementation`) → after-screenshot at the same
page/breakpoint → compare with the before-image → commit
`fix(burnish): ISSUE-NNN — <desc>`, one commit per fix.
Regression (anything else visually broke) → revert that commit, mark the
finding deferred with both screenshots. Never bundle fixes.

## 5. Re-score + report

Re-capture the affected baselines. Write `reports/burnish-report.md`
(envelope kind: test-report, agent: controller) — score before → after,
findings table (fixed / deferred / open) with before/after screenshot pairs
— plus the machine twin `reports/burnish-report.json` (same findings shape
as guild-verdict.json + scores). Log:
`ledger.sh append burnish <slug> audit <PASS|FAIL|PARTIAL> reports/burnish-report.md`
(PASS = no Critical/High open). Update STATE.md.

## Red flags

| Thought | Reality |
|---|---|
| "I can judge the design from the source code" | Design lives in rendered pixels. No live target, no burnish. |
| "The finding is obvious, skip the screenshot" | Unproven findings are opinions. The screenshot is the finding. |
| "While fixing spacing I'll also restructure the component" | Surgical or nothing — every changed line traces to a finding. |
| "It looks better now, ship all fixes in one commit" | One commit per fix or reverting a regression takes the good fixes with it. |
| "No DESIGN.md, so anything goes" | Heuristics are declared up front, then applied consistently — taste with a paper trail. Offer `/smithy:pattern` after. |

Handoff: "Report + evidence in `reports/`. Open Critical/High → another burnish round or `/smithy:forge`; no DESIGN.md yet → `/smithy:pattern` locks the system so the next burnish measures instead of judging."
