---
name: wield
description: "Functional QA as a user: mandatory screenshots, 0-100 health score, persona flows, severity tiers. Triggers: 'wield', 'QA this', 'does it work'."
---

# Wield — Functional QA

(You wield the blade the way a user would.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append temper <slug> wield STARTED -`

## Process

1. **Detect stack + surface:** `stack-detect.sh`. Playbook from this skill's
   `references/` dir by `stack=`: `ts.md`, `python.md`, `go.md`, `java.md`,
   `rust.md` (any web UI can additionally use Playwright via npx per ts.md).
   Web UIs and services need a runnable target — get the run command + URL
   from spec.md / STATE.md or ask.

2. **Pick the tier** (AskUserQuestion, default Standard):
   - **Quick** — fix-worthy findings: Critical + High only
   - **Standard** — + Medium
   - **Exhaustive** — + Low/cosmetic

3. **Derive the flow list** from spec.md success criteria (pipeline mode) or
   from the user (standalone). Each flow: steps, expected outcome, edge and
   error variants. No invented requirements — flows trace to the spec.

   **Persona mode — automatic when `docs/smithy/personas/` exists** (created
   by `/smithy:commission`; offer to run it if absent on a multi-role app):
   - Derive flows PER persona from each persona's jobs-to-be-done, executed
     within that persona's permission boundary (their credentials/role).
   - Add **cross-persona checks**: every `CANNOT` in a persona file becomes a
     test that the action/data is actually denied — a CANNOT that succeeds
     is a Critical finding, whatever else passes.
   - Severity uses the persona's own calibration section (a finding's cost
     is the persona's stake, not the developer's guess).
   - The report groups findings by persona; the health score stays global.

4. **Write the test brief** (`briefs/wield.md`): playbook path, flows, tier,
   persona file paths when in persona mode, report path `reports/test-qa.md`,
   and — for any browser/UI target — the MANDATORY evidence dir
   `docs/smithy/jobs/<slug>/reports/qa-evidence/`. The brief states the
   evidence contract explicitly: one screenshot per flow at its assertion
   point, before/after pairs for mutating actions, one screenshot per
   finding named `issue-NNN-<what>.png`. A UI QA report with zero
   screenshots is INVALID — reject it and re-dispatch with the gap named.
   Dispatch `smithy:temperer` (routing role `testing`).

5. **Score the report.** Findings carry: severity (Critical/High/Medium/Low),
   confidence 1–10 (9–10 = verified against code/behavior), and fingerprint
   `sha256(category + file + normalized title)` (first 12 hex chars) for
   cross-run trends. Health score per category, 0–100:
   start at 100; deduct Critical −25, High −15, Medium −8, Low −3 (floor 0).
   Categories & weights: Functional 35, Error handling 20, UX/Output 15,
   Content 10, Performance 10, Accessibility 10 (skip N/A categories and
   renormalize). Overall = weighted average.

6. **Write the machine-readable twin** `reports/test-qa.json`: findings
   (fingerprint, persona if persona-mode, severity + severity_reason,
   confidence, flow, evidence {type: screenshot|command, path, detail},
   fix, status) + health score per category and overall — same shape as
   guild-verdict.json findings.

7. **Trend.** If a previous `reports/test-qa.json` exists, match
   fingerprints: Resolved / Persistent / New; report score delta
   (baseline → now).

8. **Log:** `ledger.sh append temper <slug> wield <PASS|FAIL|PARTIAL> reports/test-qa.md`
   (FAIL if any Critical/High is open; PARTIAL if some flows could not run).

## Fix routing

Fixes go through `/smithy:forge` as tier-filtered tasks, one commit per fix:
`fix(qa): ISSUE-NNN — <desc>`. If a fix causes a regression, revert it and
mark the issue deferred. Never bundle fixes.

Handoff: "Score X/100, N findings. Fixes → `/smithy:forge`; next: `/smithy:proof` if a service exists."
