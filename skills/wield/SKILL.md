---
name: wield
description: Functional QA of the built feature as a user would exercise it — flows, edge inputs, error paths — with severity-tiered findings and a 0-100 health score. Use when asked to "wield", "QA this", "does it actually work", "test the app", or as part of /smithy:temper.
---

# Wield — Functional QA

(You wield the blade the way a user would.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append temper <slug> wield STARTED -`

## Process

1. **Detect stack + surface:** `stack-detect.sh`. Playbook: `references/ts.md`
   (web UI / Node API) or `references/python.md` (Python API/CLI). Web UIs and
   services need a runnable target — get the run command + URL from spec.md /
   STATE.md or ask.

2. **Pick the tier** (AskUserQuestion, default Standard):
   - **Quick** — fix-worthy findings: Critical + High only
   - **Standard** — + Medium
   - **Exhaustive** — + Low/cosmetic

3. **Derive the flow list** from spec.md success criteria (pipeline mode) or
   from the user (standalone). Each flow: steps, expected outcome, edge and
   error variants. No invented requirements — flows trace to the spec.

4. **Write the test brief** (`briefs/wield.md`): playbook path, flows, tier,
   report path `reports/test-qa.md`. Dispatch `smithy:tester` (routing role
   `testing`).

5. **Score the report.** Findings carry: severity (Critical/High/Medium/Low),
   confidence 1–10 (9–10 = verified against code/behavior), and fingerprint
   `sha256(category + file + normalized title)` (first 12 hex chars) for
   cross-run trends. Health score per category, 0–100:
   start at 100; deduct Critical −25, High −15, Medium −8, Low −3 (floor 0).
   Categories & weights: Functional 35, Error handling 20, UX/Output 15,
   Content 10, Performance 10, Accessibility 10 (skip N/A categories and
   renormalize). Overall = weighted average.

6. **Trend.** If a previous `reports/test-qa.md` exists, match fingerprints:
   Resolved / Persistent / New; report score delta (baseline → now).

7. **Log:** `ledger.sh append temper <slug> wield <PASS|FAIL|PARTIAL> reports/test-qa.md`
   (FAIL if any Critical/High is open; PARTIAL if some flows could not run).

## Fix routing

Fixes go through `/smithy:forge` as tier-filtered tasks, one commit per fix:
`fix(qa): ISSUE-NNN — <desc>`. If a fix causes a regression, revert it and
mark the issue deferred. Never bundle fixes.

Handoff: "Score X/100, N findings. Fixes → `/smithy:forge`; next: `/smithy:proof` if a service exists."
