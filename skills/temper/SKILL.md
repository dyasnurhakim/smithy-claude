---
name: temper
description: "Full test pass: runs ring-test, wield, proof and hone (skipping, with the reason, any suite that cannot run) and gives one READY or NOT READY verdict. Works inside a job or on its own. Triggers: 'temper', 'test everything', 'full test pass'."
---

# Temper — Full Test Pass

Tempering puts metal under controlled stress until it holds. Here: run
every test suite that can run, then give ONE verdict.

```
stack ─▶ choose suites ─▶ ring-test ─▶ wield ─▶ proof ─▶ hone ─▶ temper-summary.md
         (minus testing.skip,  unit       QA      load     speed     READY | NOT READY
          minus missing needs = SKIPPED + reason)
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh temper auto` — read its summary.
   Note the slug; every suite runs under it.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`, `${CLAUDE_PLUGIN_ROOT}/references/envelope.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| A known stack | `stack-detect.sh` gives one `stack=` | `stack=unknown`, `also=` (mixed repo), or a result that contradicts the repo → confirm with the user |
| Each suite's must-haves (table below) | run the suite | mark it **SKIPPED** with the reason. That is not a temper failure — the summary lists it as a gap |
| An active job | test that job | start.sh made a new slug; scope comes from each suite's own Needs |

| Suite | Must-haves (else SKIPPED) |
|---|---|
| ring-test | a test runner or a test command from the user |
| wield | a running target (UI / service) or a CLI command |
| proof | a running service, a local or user-approved target, limits from the user |
| hone | at least one concrete operation to measure |

## Steps

1. **Stack** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh`; show the
   line; confirm per Needs.
   → verify: the stack line is shown (and confirmed if unclear).

2. **Choose the suites** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get testing.skip`
   (merges defaults → global → project; never read a config file directly).
   Suites in `testing.skip` are SKIPPED (reason: config). Ask the user
   (multi-select) about the rest, with these picked by default:
   - ring-test — always;
   - wield — always;
   - proof — only if a runnable service exists: the LATEST line starting
     `run:` in `<memory>/decisions.md` (`run: <start command> | url: <url>`);
     missing → ask the user once, then append that line;
   - hone — if the job touched hot paths or the user cares about speed.
   A suite the user drops is SKIPPED (reason: user). Then check each chosen
   suite's must-haves; missing → SKIPPED with the exact reason.
   → verify: every one of the four suites is marked run or SKIPPED + reason.

3. **Resume check** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail 30`. A
   suite with a result line for this job and no code change since
   (`git log`) keeps that report. After a fix (e.g. from anneal), re-run only
   the failing suite, then rebuild the summary.
   → verify: you can name which suites run now and which reports are reused.

4. **Run the suites in order** ring-test → wield → proof → hone. Each follows
   its own SKILL.md and starts with `start.sh <suite> <temper's slug>`; each
   writes its own report and ledger line. A FAIL does not stop the rest (all
   the facts first) — EXCEPT: wield found an open Critical → proof is
   SKIPPED (reason: do not load-test a broken app).
   → verify: each run suite has its ledger line and report.

5. **Write the summary** `jobs/<slug>/reports/temper-summary.md` — envelope
   (`kind: test-report`, `unit: summary`, `agent: controller`; carry
   forward open `key_facts` / `concerns` from the suite reports), then:

   ```markdown
   # Temper Summary — <job> — <date>
   Stack: <stack-detect line>
   | Suite | Status | Report | Headline |
   |-------|--------|--------|----------|
   | ring-test | PASS / FAIL / PARTIAL / SKIPPED (<reason>) | reports/test-unit.md | <one line> |
   | wield | … + health score X/100 | reports/test-qa.md | |
   | proof | … | reports/test-stress.md | |
   | hone | … | reports/test-perf.md | |
   ## Verdict: READY | NOT READY
   ## Gaps
   <skipped suites and why, criteria with no test, findings left open>
   ```

   **Verdict:** READY only when every suite that ran is PASS and at least
   one suite ran. Any FAIL or PARTIAL → NOT READY. Never soften it.
   → verify: the verdict follows from the table, and every SKIPPED row has a reason.

6. **Log and update** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append temper <slug> summary <PASS|FAIL|PARTIAL> jobs/<slug>/reports/temper-summary.md`
   (PASS = READY; FAIL = any suite FAIL; PARTIAL = a suite PARTIAL and none
   FAIL). Rewrite STATE.md: phase TEMPER done, next step.
   → verify: `ledger.sh tail 1` shows the line; STATE.md names the next step.

## Done when

- [ ] the stack line is shown
- [ ] all four suites are marked: run (with report) or SKIPPED (with reason)
- [ ] each run suite has its own ledger line under its own name
- [ ] `temper-summary.md` written with one READY / NOT READY verdict that follows the rule
- [ ] gaps (skipped suites, untested criteria) are listed, not hidden
- [ ] ledger line under `temper`; STATE.md updated

## Output

`jobs/<slug>/reports/temper-summary.md` (plus each suite's own report).

`Next: /smithy:anneal — find why <suite> fails (report: <path>)` · or `Next: /smithy:handover — READY; save the session`.

## Red flags

| Thought | Reality |
|---|---|
| "Rerun it — it might pass this time" | Never rerun for a better number without a change in between. Pass-on-rerun is a flake. |
| "Only hone failed, so it's basically READY" | One failing suite that ran = NOT READY. |
| "Skip proof quietly, there's no service" | SKIPPED is fine — with the reason, in the summary. |
