---
name: anneal
description: "Debugging: reproduce → read-only root-cause analysis → the user approves the fix → regression test first (jigsmith) → ONE review. Triggers: 'anneal', 'debug', 'why is this broken', a failing test or run with an unknown cause."
---

# Anneal — Debug by Root Cause

**Iron law: root cause before fix. Always.** No fix is written, offered as
final, or dispatched until a reproduced root cause exists. A fix without a
root cause is a guess.

```
symptom + repro ─▶ annealer (read-only) ─▶ ROOT_CAUSE_FOUND ─▶ user approves the fix
                        │ CANNOT_REPRODUCE / INCONCLUSIVE ─▶ more evidence, or the user
                        ▼
   jigsmith: regression test FAILS (RED) ─▶ fix ─▶ PASSES (GREEN) ─▶ ONE review ─▶ repro passes
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh anneal new` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`.
3. Save the start sha: `git rev-parse HEAD` → write it down. The review
   diffs from it; anneal never runs `record-base` (that would overwrite the
   active job's base).
4. STATE.md: note the current `Phase` line (you restore it at the end),
   then set Phase ANNEAL. Leave Active job and Base sha alone.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| A symptom + an exact repro command | from the user or a failing report (forge task, temper suite) | ask, or derive it from the failing test. "It sometimes breaks" is not a symptom; "this command printed this output" is. No repro after asking → stop and say exactly what is missing (command, env, data, timing) |
| Where it broke (job + unit) | note it for the return trip | standalone bug: none |
| A test runner | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh` finds it | ask for the test command |
| A clean working tree (before the fix) | continue | show `git status --short` and ask; never stash on your own |
| Commit approval for the fix | — | the user's "apply" in step 5 |

## Steps

1. **Failure context** — write `<memory>/jobs/<slug>/reports/rca-<n>-context.md`:

   ```markdown
   # Failure Context
   ## Symptom
   <one sentence: observable behavior>
   ## Repro command
   `<command>` → actual: <output> | expected: <output>
   ## Broke in
   <job + unit (e.g. user-auth task-3, temper ring-test) | standalone>
   ## Recent history
   <ledger tail 10; recent related commits — when did it last work?>
   ## Leads (unverified — from lookup or the user)
   ## Suspect files (guesses, not conclusions)
   ```
   → verify: the file has a symptom and a repro with actual vs expected.

2. **Lookup** (creed §10, once) — memory: search by the error text for past
   bug fixes; graph: callers of the suspect code. Put hits under Leads with
   their source (`claude-mem #ID`). None installed → say so.
   → verify: Leads filled with sources, or "no lookup tool".

3. **Dispatch the `annealer`** (read-only; it never fixes). Pick its lens
   by symptom (`${CLAUDE_PLUGIN_ROOT}/references/persona-modes.md`) and add it as `## Persona` in
   the context file: ordinary logic bug →
   `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/engineer.md`; security-flavored →
   `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/security.md`; prod/infra/resources →
   `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/sre.md`; "users are confused" →
   `${CLAUDE_PLUGIN_ROOT}/references/personas/patrons/end-user.md`. Dispatch per
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §1–2 (role `debugging`); prompt = banner +
   paths (context file, creed, report `jobs/<slug>/reports/rca-<n>.md`) +
   "Job <slug>, rca-<n>".
   → verify: `envelope.sh get <report> status` prints a status.

4. **Handle the RCA status:**

   | Status | What you do |
   |---|---|
   | ROOT_CAUSE_FOUND | → step 5 |
   | CANNOT_REPRODUCE | Show what the annealer ran and saw. Ask the user for more signal: exact env, data, timing, versions. Never guess-fix: a fix for a bug you cannot reproduce cannot be checked. |
   | INCONCLUSIVE | Show the hypotheses, ranked, with their evidence. Ask which to chase or what context was missing; re-dispatch ONCE with the new context. A second INCONCLUSIVE → the user decides the next move. |
   → verify: you are at step 5 with ROOT_CAUSE_FOUND, or the user has the evidence and a question.

5. **Approve the fix.** Show the user: the mechanism (`file:line` — what
   happens and why it gives the symptom), the minimal fix, the regression
   test. Ask: apply / revise / stop. Say **"Apply authorizes the fix
   commit."** On apply: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh status`
   (note any existing grant), then `guard.sh grant <slug>`. Log the decision
   in `<memory>/decisions.md` (≤3 lines).
   → verify: the user said apply; `guard.sh status` shows the grant.

6. **Fix — test first, always (jigsmith).** Write
   `jobs/<slug>/briefs/fix-<n>.md` per `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3 plus
   jig's brief lines with `<unit>` = `fix-<n>` (skills/jig/SKILL.md § Brief
   lines; read its three settings once, jig § The three settings). Requirements = the RCA's
   regression test (it must FAIL first — it IS the bug, reproduced) and the
   minimal fix EXACTLY as approved. Verify = the original repro (now passes)
   + the project's test suite. Dispatch the `jigsmith` (role
   `implementation`), handle the status (§4), then:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tdd-snap.sh verify <slug> fix-<n>` must print `OK`.
   → verify: `tdd-verify: OK`; one fix commit in `git log --oneline <start-sha>..HEAD`.

7. **ONE review** — `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §5 with the fix brief:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh build --base <start-sha> <memory>/jobs/<slug>/briefs/fix-<n>.md <memory>/jobs/<slug>/reports/review-pkg.md`
   ONE `inspector` with the "Do Not Trust the Reports" line and the TDD
   commits mode. Judge the findings (`/smithy:inspect` § Judging findings).
   REJECTED → fix rounds per §6, budget `implementation.max_fix_cycles`;
   spent → stop and show the user both reviews.
   → verify: both verdicts APPROVED, or the user decided.

8. **Prove and log.** Run the original repro command yourself — it must
   pass. `ledger.sh append anneal <slug> rca-<n> DONE jobs/<slug>/reports/rca-<n>.md`
   and `ledger.sh append anneal <slug> fix-<n> DONE <fix report>`. Grant: one
   existed in step 5 → restore it (`guard.sh grant <that job>`). None existed
   → `guard.sh revoke` only if `guard.sh status` shows the grant names
   `<slug>` (this job); another job's grant → leave it. STATE.md: restore the
   Phase you noted at Start (none → IDLE); another job active → leave its
   Active job and Base sha alone and set Next step to "re-run <the unit that
   broke>".
   → verify: the repro output shows the expected result; the ledger lines
   exist; STATE.md Phase is no longer ANNEAL.

## Done when

- [ ] the context file has a symptom and a repro (actual vs expected)
- [ ] the RCA report says ROOT_CAUSE_FOUND with a mechanism at `file:line`
- [ ] the user approved the fix; the decision is in decisions.md
- [ ] `tdd-verify: OK` for `fix-<n>` (the regression test failed first, then passed)
- [ ] one review from the start sha: both verdicts APPROVED, or the user decided
- [ ] the original repro passes (paste the line you ran and its result)
- [ ] ledger lines written; grant restored, or revoked only if it was this job's; another job's base untouched
- [ ] STATE.md Phase restored (or IDLE)

If the skill stops at CANNOT_REPRODUCE or INCONCLUSIVE, say so plainly with
the evidence and the question — that is an honest end, not a fix.

## Output

`jobs/<slug>/reports/rca-<n>-context.md` · `rca-<n>.md` · `briefs/fix-<n>.md`
· the fix report · the review report.

- An active pipeline job → hand back to it:
  `Next: /smithy:forge — re-run the unit that broke (or the failing /smithy:temper suite)`
- Standalone (no other job active): `Next: none — <what to check>`

## Red flags

| Thought | Reality |
|---|---|
| "I can see the bug, skip the RCA" | You see A cause. The annealer proves it is THE cause — mechanism, not feeling. |
| "It's a one-line fix, the process is overkill" | One-line fixes without RCA are how the same bug comes back. |
| "Can't reproduce, but the fix is probably right" | An unreproduced fix cannot be checked. CANNOT_REPRODUCE goes to the user, not to a guess. |
| "The regression test can come later" | Later means never. RED is the regression test — it comes FIRST. |
| "Two bugs look related, I'll fix both" | One symptom, one RCA, one fix. Note the second bug; do not widen the diff. |
| "INCONCLUSIVE — I'll just take hypothesis 1" | The evidence does not decide it. Get more evidence or ask. |
| "I'll record-base for a clean review" | That overwrites the active job's base. Use the start sha and `--base`. |
