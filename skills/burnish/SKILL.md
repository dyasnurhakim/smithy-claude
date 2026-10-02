---
name: burnish
description: "Design review and polish: screenshot the live local UI, judge it against DESIGN.md (or stated rules), score it, and send the fixes the user approves through strike — with before/after screenshots as proof. Triggers: 'burnish', 'polish the UI', 'design review'."
---

# Burnish — Design Review & Improvement

Burnishing polishes finished metal. The piece exists; you make its surface
right. Design lives in rendered pixels, so every finding is a screenshot.

```
screenshots ──▶ judge vs DESIGN.md ──▶ score ──▶ USER PICKS ──▶ /smithy:strike ──▶ after-shots ──▶ report
(before)        (or stated rules)               (the gate)     (fix, test, ONE review)  (proof)
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh burnish new` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/envelope.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/designer.md` (you judge as this persona).
   Read `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` only if step 2 dispatches an inspector.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| The UI running LOCALLY (run command + URL) | the Run line (`${CLAUDE_PLUGIN_ROOT}/references/memory-card.md` § Run line) — confirm it loads | **stop**: say "burnish needs the app running locally — start it (e.g. `npm run dev`) and give me the URL". Never a remote or production URL |
| Playwright via npx | `npx --no-install playwright --version` prints a version | **stop**: say "Playwright is missing — run `npx playwright install chromium` (fetches Playwright and a browser), then run burnish again". The user runs it |
| The design standard | `<memory>/DESIGN.md` — drift from it is a finding citing its line | judge by the stated rules in step 2 AND say so in the report; offer `/smithy:pattern` at the end |
| Which pages and states | the user names them | default: the main pages + one form, one empty state, one error state — confirm the list |
| A past burnish report (the baseline) | slugs differ each run, so glob `jobs/*/reports/burnish-report.json`, skip this job's, take the newest by mtime; compare fingerprints with it | every finding is New |
| Commit approval | not burnish's job — burnish never edits | strike asks once; that yes is the commit grant (`guard.sh grant`) |

Paths below are relative to the `memory:` folder start.sh printed.
Evidence folder: `jobs/<slug>/reports/burnish-evidence/`.

## Steps

1. **Before screenshots** — each page at widths 320, 768 and 1440:
   `npx playwright screenshot --viewport-size=<w>,720 <url> <evidence>/base-<page>-<w>.png`.
   States that need clicks or typing → a scratch Playwright script kept in
   the evidence folder (never in the project's tests).
   → verify: one `base-*.png` per page × width; list any page that failed to load.

2. **Judge** — standard first, then eyes. Lookup (creed §10): memory —
   past burnish findings and design decisions for these screens.
   With DESIGN.md: its tokens, states and voice. Without it, these stated rules:
   - **Hierarchy**: one clear main action or message per view; real size contrast.
   - **Rhythm**: one spacing scale; things line up on a grid; no stray margins.
   - **Consistency**: same radius, shadow, spacing and words for the same thing.
   - **States**: hover, focus, active, disabled designed; loading, empty, error present.
   - **Accessibility**: contrast (compute it), visible focus, touch targets,
     main flows usable by keyboard.
   - **Anti-template**: the banned list in `/smithy:pattern` § Anti-template
     gate (stock look, uniform card grids, gray + one accent, undesigned
     states, the three AI clichés) showing up as unexamined defaults.
   - **Distinctiveness**: is there a signature element, or would this fit any
     product? Copy: the user's words, the same action names, errors that
     direct instead of apologize.
   - **Responsive**: no overflow or breakage at the three widths.
   Large apps: also dispatch ONE `inspector` (role `review`; read
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` now and follow §1–2) with `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/designer.md`
   as its overlay and the before screenshots as live evidence; merge its
   findings into yours.
   → verify: every finding has proof (next list).

   Every finding carries:
   - proof: screenshot path + the region it shows;
   - why it is flagged (the DESIGN.md line or the rule above);
   - severity + because — Critical = a group of users is blocked or data is
     lost; High = a main flow is worse, or a WCAG AA failure; Medium = a
     consistency or rhythm break; Low = polish;
   - confidence 1–10;
   - category (one of the five below) and fingerprint per
     `${CLAUDE_PLUGIN_ROOT}/references/envelope.md` § Finding fingerprint (file = the route or
     screen name). Against the baseline report (Needs): Resolved / Persistent / New.

3. **Score** — the burnish design score. Scoring method from
   `/smithy:wield`: each category starts at 100; deduct Critical −25,
   High −15, Medium −8, Low −3 (floor 0). Burnish's own design categories
   and their weights in the overall score:

   | Visual | UX | A11y | Consistency | Responsive |
   |---|---|---|---|---|
   | 25% | 25% | 20% | 15% | 15% |

   → verify: five category scores and one overall score, each traceable to findings.

4. **Gate — findings before fixes** — first write the pre-fix report:
   `jobs/<slug>/reports/burnish-report.md` + `burnish-report.json` in the
   step 7 format, with the before score and every finding open. Then show
   the score, the findings table (severity, confidence, evidence path) and
   the improvement plan (finding → intended change → risk). Ask: fix all /
   pick some / stop at the report. **Burnish never edits without this yes.**
   → verify: both report files exist BEFORE any strike call; the user's
   choice is recorded in the report.

5. **Fix through `/smithy:strike`** — pass strike the pre-fix report
   `jobs/<slug>/reports/burnish-report.md` as its findings file, and name the
   approved findings in severity order. Each item = finding id + files + evidence screenshot +
   the DESIGN.md line or rule + the SMALLEST change that fixes it (no
   drive-by refactors). Strike confirms once (the commit grant), builds one
   commit per item, runs its tests, then ONE `inspector` review of the fix
   diff (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §5) with fix rounds up to
   `implementation.max_fix_cycles`. More items than strike takes → run it
   in rounds, highest severity first.
   → verify: strike's report lists each item as committed or deferred.

6. **After screenshots** — retake every fixed page at the same widths:
   `<evidence>/after-<page>-<w>.png`. A finding is fixed only when its
   after-shot shows it. Anything else that looks broken now = a regression:
   mark that finding deferred with both screenshots, and ask the user
   before `git revert <sha>` of that item's commit (one commit per item
   keeps the good fixes safe).
   → verify: a before/after pair for every fixed finding.

7. **Report** — update the step 4 report `jobs/<slug>/reports/burnish-report.md`: envelope
   (`kind: test-report`, `unit: audit`, `agent: controller`), first body
   line `Status:`, then score before → after, the findings table (fixed /
   deferred / open, fingerprint, before/after pair), the standard used
   (DESIGN.md or stated rules). Machine twin `burnish-report.json`: the
   same finding shape as `guild-verdict.json`, plus the scores.
   Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append burnish <slug> audit <PASS|FAIL|PARTIAL> jobs/<slug>/reports/burnish-report.md`
   (PASS = no Critical/High open; FAIL = some open; PARTIAL = some pages could not be captured).
   STATE.md: only if start.sh showed `active=none`, rewrite it for this job
   (Phase IDLE, Next step). Otherwise another job owns STATE — leave it alone.
   → verify: both report files exist; `envelope.sh validate` passes; ledger line written.

## Done when

- [ ] the app was local and loaded; before screenshots exist for every page × width
- [ ] the standard was named (DESIGN.md, or the stated rules)
- [ ] every finding has a screenshot, severity + because, confidence and fingerprint
- [ ] five category scores + overall, before (and after, if fixes ran)
- [ ] the user's gate choice is recorded; nothing was edited without it
- [ ] fixes (if any) went through strike: one commit per item, one inspector review
- [ ] every fixed finding has a before/after pair; regressions are deferred with both shots
- [ ] `burnish-report.md` + `burnish-report.json` written; ledger line written

## Output

`jobs/<slug>/reports/burnish-report.md` · `burnish-report.json` ·
`burnish-evidence/` (before/after screenshots) · strike's report, if fixes ran.

`Next: /smithy:pattern — no DESIGN.md yet, lock the system so the next burnish measures instead of judging` · or `Next: /smithy:burnish — open Critical/High remain` · or `Next: none — check the after screenshots`.

## Red flags

| Thought | Reality |
|---|---|
| "I can judge the design from the source code" | Design lives in rendered pixels. No live local app, no burnish. |
| "The finding is obvious, skip the screenshot" | A finding without proof is an opinion. The screenshot is the finding. |
| "While fixing spacing I'll also restructure the component" | Small and exact or nothing — every changed line traces to a finding. |
| "It looks better now, ship all fixes in one commit" | One commit per item, or reverting a regression takes the good fixes with it. |
| "The fixes are tiny, I'll edit them myself" | Fixes go through strike so they are tested and reviewed. |
| "No DESIGN.md, so anything goes" | State the rules first, then apply them the same way everywhere. |
