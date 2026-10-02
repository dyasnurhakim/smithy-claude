---
name: strike
description: "Fix lane for small KNOWN changes and for review/QA findings: mini plan → one yes → bug items test-first (jigsmith), other items by the forger → targeted tests → ONE review → one report. No spec needed. Triggers: 'strike', 'quick fix', 'fix these items', 'fix these findings', 'small change'."
---

# Strike — Small Known Fixes

One sure hammer blow — for work that needs an anvil, not the whole forge.
Same agents, briefs, statuses and guard as forge (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
binds). What strike skips is the ceremony: spec, task breakdown, persona
pass. Never the evidence.

```
items, or a findings report ─▶ mini plan ─▶ ONE yes (= commit grant)
   ─▶ per item:  bug ─▶ jigsmith (failing test first) ─┐
                 other ─▶ forger ──────────────────────┴─▶ targeted tests
   ─▶ ONE review (start sha ──▶ HEAD) ─▶ fix rounds ─▶ strike-report.md
```

| Situation | Lane |
|---|---|
| Review/QA/guild findings, copy fixes, config tweaks, small refactors, bugs with a KNOWN cause | **strike** |
| Cause unknown, "why is this broken", flaky failures | `/smithy:anneal` — strike never guess-fixes |
| New behavior, anything spec-shaped | `/smithy:assay` |
| More than ~5 items, or one item over ~100 changed lines | `/smithy:blueprint` — that is a plan |

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh strike new` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`, `${CLAUDE_PLUGIN_ROOT}/references/envelope.md`.
3. Save the start sha: `git rev-parse HEAD` → write it down. The review
   diffs from it; strike never runs `record-base` (that would overwrite
   another job's base).

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| What to fix | the user's list, OR a findings report path (`review.md`, a guild/wield/burnish report) | ask what to fix |
| A findings report | read its findings table. Default items = Critical/High; show the rest and let the user pick. Keep each finding's number or fingerprint (`${CLAUDE_PLUGIN_ROOT}/references/envelope.md` § Finding fingerprint) on its item | — |
| A known cause per item | plan it | move it to an "→ anneal" list and tell the user |
| Size: ≤5 items, each ≤~100 lines | continue | recommend `/smithy:blueprint` (or split into two strikes) |
| A test runner | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh` finds it | ask for the test command |
| A clean working tree | continue | show `git status --short` and ask; never stash on your own |
| Commit approval | — | the plan yes in step 2 |

## Steps

1. **Plan — short, inline.** Per item: the files, the approach in one line,
   its kind (`bug` = wrong behavior to correct; `change` = anything else),
   and a concrete check. Write `<memory>/jobs/<slug>/plan.md`:

   ```markdown
   # Strike Plan — <slug>
   Source: <findings report path | the user's request>
   1. [bug] <item> (finding #2 · <fingerprint>) — files: <paths> — approach: <one line> → verify: `<command>`
   2. [change] <item> — files: <paths> — approach: <one line> → verify: `<command>`
   ## Test scope (step 5)
   <the affected test files/suites + every verify command>
   ## → anneal (cause unknown)
   ```
   → verify: every item has files, a kind and a verify command.

2. **One gate.** Show the plan. Ask: approve all / trim items / abort. Say
   **"Approving authorizes these items' commits."** On yes: run
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh status` and note any grant
   that already exists (a pipeline's), then `guard.sh grant <slug>`.
   → verify: `guard.sh status` shows the grant for `<slug>`.

3. **Lookup** (creed §10, once, per `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3) — memory:
   past bugs and decisions on the items' files or error text; graph: callers
   of what will change. Facts go into each brief's `key_facts` with sources.
   → verify: `key_facts` filled with sources, or `[]`.

4. **Build, item by item, in order.** One brief per item at
   `jobs/<slug>/briefs/task-N.md` (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3; requirements
   = this item only, as observable behavior; `## Persona` =
   `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/engineer.md` + at most one specialist per
   `${CLAUDE_PLUGIN_ROOT}/references/persona-modes.md`). Dispatch per §1–2 (role
   `implementation`); handle statuses per §4 — NEEDS_CONTEXT still gets an
   answer, never a guess.
   - **`bug` item → `jigsmith`, always test-first.** Add jig's brief lines
     (skills/jig/SKILL.md § Brief lines; read its three settings once, jig §
     The three settings). The failing test reproduces the bug. After:
     `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tdd-snap.sh verify <slug> task-N` must print `OK`.
   - **`change` item → `forger`, no TDD** — even when `implementation.tdd`
     is `always`. Say so in one line; skipping that ceremony is this lane's point.

   One commit per item (`fix:` / `chore:` / `docs:` as fits).
   `ledger.sh append strike <slug> task-N <STATUS> <report>`.
   → verify: `git log --oneline <start-sha>..HEAD` shows one commit per item; bug items print `tdd-verify: OK`.

5. **Test — targeted, not a full temper.** Run the plan's test scope: every
   verify command plus the tests that cover the touched code (the project's
   runner, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`). Run the whole suite when the touched
   code is imported widely. A failure → a fix round for that item
   (re-dispatch with the failing output path in its brief). Budget:
   `config.sh get implementation.max_fix_cycles`. Still failing →
   `git revert <that commit>` (a new commit; never reset), mark the item
   deferred, tell the user why.
   → verify: the summary line of each run is in the report.

6. **ONE review of the whole diff** — `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §5, from the
   start sha, with the plan as the brief:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh build --base <start-sha> <memory>/jobs/<slug>/plan.md <memory>/jobs/<slug>/reports/review-pkg.md`
   ONE `inspector` (role `review`) with the "Do Not Trust the Reports" line;
   name the TDD commits mode if bug items ran. Judge the findings
   (`/smithy:inspect` § Judging findings). REJECTED → fix rounds per §6:
   budget `implementation.max_fix_cycles`, then review only the fix diff
   (`--base <sha before the round>`). Spent → stop; show the user both
   reviews. Skip the review ONLY if the user says so — then say what was skipped.
   → verify: a review report with both verdicts APPROVED, or the user decided.

7. **Report** — write `jobs/<slug>/reports/strike-report.md`: envelope
   (`kind: forge-report`, `unit: strike`, `agent: controller`; carry forward
   open `key_facts`/`concerns`), then an items table (item · source finding ·
   kind · builder · done/deferred/reverted · commit · verify result), the
   review verdicts, and the "→ anneal" list. Delete per-item scratch
   (`reports/task-*-impl.md`, `reports/review-pkg*.md`; keep `reports/raw/`
   and the review). Grant: a grant existed in step 2 → restore it
   (`guard.sh grant <that job>`). None existed → `guard.sh revoke` only if
   `guard.sh status` shows the grant names `<slug>` (this job); another
   job's grant → leave it (one grant file per project).
   `ledger.sh append strike <slug> report DONE jobs/<slug>/reports/strike-report.md`.
   STATE.md: no other job active → this job, Phase STRIKE, next step. Another
   job active → leave its Active job and Base sha alone (the ledger has it).
   → verify: `strike-report.md` exists; `guard.sh status` matches what step 2 found.

## Done when

- [ ] plan.md has files, kind and a verify command per item, and the user approved it
- [ ] one commit per done item (`git log --oneline <start-sha>..HEAD`)
- [ ] every bug item: `tdd-verify: OK` (paste the lines)
- [ ] targeted tests green (summary lines), or the failing item reverted, deferred and named
- [ ] one review from the start sha: both verdicts APPROVED, or the user decided / skipped it explicitly
- [ ] strike-report.md written; scratch deleted; grant restored, or revoked only if it was this job's
- [ ] ledger DONE line; STATE.md's Base sha untouched by this skill

## Output

`<memory>/jobs/<slug>/reports/strike-report.md` · the review report ·
`reports/raw/` (test and TDD logs). Deferred items: `/smithy:anneal` (cause
unknown) or `/smithy:blueprint` (bigger than it looked). In a pipeline,
hand the report path back to the orchestrator.

`Next: none — check the deferred and "→ anneal" lists in strike-report.md`

## Red flags

| Thought | Reality |
|---|---|
| "This item needs a little investigation first" | Investigation = unknown cause = anneal. Strike items are KNOWN changes. |
| "The bug is obvious, skip the failing test" | Bug fixes are always test-first. The failing test proves the fix fixes THIS bug. |
| "Skip the tests, the changes are tiny" | Tiny changes break imports too. The test scope is in the plan — run it. |
| "No TDD for changes, so evidence is optional" | Verify commands still run; their output still goes in the report. |
| "Eight small items is still a strike" | Five is the cap. Above that you are planning — use blueprint. |
| "I'll record-base so the review is easy" | That overwrites another job's base. Use the start sha and `--base`. |
