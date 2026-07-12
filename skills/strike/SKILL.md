---
name: strike
description: "One-shot fix lane: small known changes without a spec — lightweight plan → one confirmation → forge (no TDD) → targeted tests → one report. Triggers: 'strike', 'quick fix', 'fix these items', 'small change', review/QA finding fixups."
---

# Strike — One-Shot Fixes

(One decisive hammer blow. For work that needs an anvil, not the whole forge.)

Strike is a THIN PROFILE over the forge machinery, not a separate system:
same dispatch protocol (dispatch.md is binding — briefs, file handoffs,
envelope reports, status vocabulary), same `smithy:forger` agent with routed
models, same guard grant, and an inspector review. What it skips is the
CEREMONY — assay's spec, blueprint's decomposition + persona pass, forge's
per-task review loop and TDD selection — never the subagent rules.

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
first (read-once rule applies). If `docs/smithy/` is missing, run
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.
Job slug: `strike-<YYYY-MM-DD>` (or the active job when fixing its findings).
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append forge <slug> strike STARTED -`

## When strike — and when NOT

| Situation | Lane |
|---|---|
| Known small changes: review/QA/guild findings, copy fixes, config tweaks, small refactors, obvious bugs WITH known cause | **strike** |
| Cause unknown, "why is this broken", intermittent failure | `/smithy:anneal` — strike never guess-fixes |
| New behavior/feature, anything spec-shaped | `/smithy:assay` → pipeline |
| >~5 items or any item >~100 lines of change | `/smithy:blueprint` — that's a plan, not a strike |

## Process

1. **Plan — lightweight, inline.** For EACH item: what changes (files),
   the approach in one line, and a concrete verify command. An item whose
   cause you'd have to investigate is not strike material — name it and
   route it to anneal. Write the mini-plan to
   `docs/smithy/jobs/<slug>/plan.md`:

   ```markdown
   # Strike Plan — <date>
   1. <item> — files: <paths> — approach: <one line> → verify: `<command>`
   ## Test scope (step 4)
   <the affected test files/suites + the verify commands>
   ```

2. **Confirmation — ONE gate.** Present the plan (items, files, verifies).
   AskUserQuestion: approve all / trim items / abort. State explicitly:
   "Approving authorizes these items' commits." On approval:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh grant <slug>` and
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`.

3. **Forge — plain forger, NO TDD.** This lane overrides
   `implementation.tdd` (that's its point — say so if config says always).
   Per item, in order: write a minimal brief (dispatch.md template;
   requirements = that item only; `## Persona` per persona-modes.md —
   engineer default + at most one domain specialist), dispatch `smithy:forger` exactly as
   forge's per-task loop does (routing role `implementation`, effort
   banner, paths-only prompt), one commit per item (`fix: <item>` /
   `chore:`/`docs:` as fits). Statuses per dispatch.md — NEEDS_CONTEXT
   still asks instead of guessing, even in the fast lane.

4. **Test — targeted, no TDD, no full temper.** Run the plan's test scope:
   every item's verify command + the test files covering the touched code
   (project's own runner per `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`).
   Whole-suite run when touched code is imported widely (cheap insurance).
   A failure here → the offending item gets ONE fix cycle; still failing →
   revert that item's commit, mark it deferred, tell the user why.

5. **One review, whole diff (not per item).** Build a single package
   (`review-package.sh build <plan.md> <pkg>`) and dispatch the
   `smithy:inspector` once over everything. Critical/High findings → one
   fix cycle each, then re-verify. (Skip this step ONLY if the user
   explicitly says so — say what's being skipped.)

6. **One report.** Write `reports/strike-report.md` (envelope kind:
   forge-report, unit: strike) — items table (done/deferred/reverted,
   commit, verify result), review verdict, carried concerns. No per-item
   report files survive. Then `guard.sh revoke`, ledger:
   `ledger.sh append forge <slug> strike DONE reports/strike-report.md`,
   update STATE.md.

## Red flags

| Thought | Reality |
|---|---|
| "This item needs a little investigation first" | Investigation = unknown cause = anneal. Strike items are KNOWN changes. |
| "Skip the tests, the changes are tiny" | Tiny changes break imports too. The test scope was priced into the plan — run it. |
| "TDD is off, so evidence is optional" | No. Verify commands still run, outputs still land in the report. TDD off ≠ evidence off. |
| "Eight small items is still a strike" | Five is the cap. Above that you're planning — use blueprint and get batching + review per task. |

Handoff: "Report at `reports/strike-report.md`. Deferred items → `/smithy:anneal` (unknown cause) or `/smithy:blueprint` (bigger than they looked)."
