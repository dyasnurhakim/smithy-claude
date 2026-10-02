---
name: wield
description: "Functional QA done the way a user would: run real flows, screenshots required for UI, a 0-100 health score, per-persona flows, severity tiers. Works inside a job or on its own. Triggers: 'wield', 'QA this', 'does it work'."
---

# Wield — Functional QA

You wield the blade the way a user would: click, type, call the API, and
see what really happens.

```
target running ─▶ flows (spec / user / personas) ─▶ temperer runs them ─▶ screenshots + output
                                                                         │
            test-qa.md + test-qa.json ◀── health score ◀── fingerprints ◀┘ ──▶ trend vs last run
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh wield auto` — read its summary.
   Called by temper: `start.sh wield <temper's slug>` so both log to the same job.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`, `${CLAUDE_PLUGIN_ROOT}/references/envelope.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| A running target (web UI or service) | run command + URL: the LATEST line starting `run:` in `<memory>/decisions.md` (`run: <start command> \| url: <url>`) | ask the user once, then append that `run:` line to decisions.md. If nothing can be started, **stop** and say exactly what is missing (run command, URL, login). A CLI only needs its built command |
| Success criteria | the `## Success criteria` section of `jobs/<slug>/spec.md` or `plan.md` (whichever has it) | ask the user what "works" means; write the answers as the flow list and confirm it |
| Personas | `<memory>/personas/` (from `/smithy:commission`) → persona mode | built-in lens `${CLAUDE_PLUGIN_ROOT}/references/personas/patrons/end-user.md`. On an app with several user roles, offer `/smithy:commission` once |
| A stack playbook | `stack-detect.sh` finds the stack | `stack=unknown` → general rules in `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`; any web UI can use Playwright via npx (ts playbook) |
| Last run | this job's `jobs/<slug>/reports/test-qa.json`, else the newest `jobs/*/reports/test-qa.json` (by mtime) from earlier jobs → step 7 copies it to `reports/test-qa.prev.json` for the trend | this run is the baseline — say so |

## Steps

1. **Stack and surface** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh`;
   pick the playbook by `stack=`: `${CLAUDE_PLUGIN_ROOT}/skills/wield/references/ts.md`,
   `python.md`, `go.md`, `java.md`, `rust.md`. Name the surface: web UI,
   API, or CLI. Get the run command and URL (Needs).
   → verify: playbook path, surface, and run command + URL (or CLI command) are named.

2. **Pick the tier** (ask; default Standard):

   | Tier | Findings reported |
   |---|---|
   | Quick | Critical + High |
   | Standard | + Medium |
   | Exhaustive | + Low / cosmetic |
   → verify: the tier is stated.

3. **Write the flow list** — from the success criteria (Needs), or the user's
   answers. Each flow: steps, expected result, edge and error variants.
   Flows trace to the spec or the user — never invent a requirement.
   **Persona mode** (when `<memory>/personas/` exists):
   - flows per persona, from that persona's jobs-to-be-done, run inside that
     persona's permission limits (their login / role);
   - **cross-persona checks:** every `CANNOT` in a persona file becomes a
     test that the action or data is really denied. A `CANNOT` that
     succeeds is Critical, whatever else passes;
   - severity uses that persona's own calibration section;
   - the report groups findings by persona; the health score stays global.
   → verify: every flow names its source (spec line, user answer, or persona file).

4. **Write the brief** `jobs/<slug>/briefs/wield.md` (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
   §3): playbook path, flows, tier, run command + URL, report path
   `jobs/<slug>/reports/test-qa.md`. `## Persona`:
   `${CLAUDE_PLUGIN_ROOT}/references/personas/patrons/end-user.md` + project personas (persona
   mode) + `${CLAUDE_PLUGIN_ROOT}/references/personas/patrons/support.md` when error-path flows
   are in scope (cap: 2 built-in + project personas).
   **UI target:** the brief names the evidence folder
   `<memory>/jobs/<slug>/reports/qa-evidence/` and states the rule: one
   screenshot per flow where it checks the result, a before/after pair for
   every action that changes data, one per finding (`issue-NNN-<what>.png`).
   → verify: the brief exists; UI briefs state the evidence folder and rule.

5. **Dispatch** one `temperer` (role `testing`; `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
   §1–2: banner + paths + "Job <slug>, wield"). **A UI report with zero
   screenshots is invalid** — reject it and re-dispatch once with the gap
   named; still none → tell the user.
   → verify: report exists; UI runs: `ls <memory>/jobs/<slug>/reports/qa-evidence/` lists PNGs.

6. **Score the findings** — each finding gets a severity
   (Critical/High/Medium/Low) with a reason, a confidence 1–10 (9–10 = checked
   against code or behavior), and a fingerprint as defined in
   `${CLAUDE_PLUGIN_ROOT}/references/envelope.md` § Finding fingerprint.
   **Wield health score** (other skills reuse this rubric): per category,
   start 100, deduct Critical −25, High −15, Medium −8, Low −3 (floor 0).

   | Category | Weight |
   |---|---|
   | Functional | 35 |
   | Error handling | 20 |
   | UX / Output | 15 |
   | Content | 10 |
   | Performance | 10 |
   | Accessibility | 10 |

   Skip categories that do not apply and scale the rest back to 100.
   Overall = weighted average.
   → verify: every finding has severity + reason, confidence and fingerprint; the score shows per category and overall.

7. **Write the machine-readable twin** `jobs/<slug>/reports/test-qa.json`.
   BEFORE you write it, keep the last run: copy the previous one (Needs →
   Last run) to `jobs/<slug>/reports/test-qa.prev.json`. Then write the
   findings (fingerprint, persona in persona mode, severity +
   severity_reason, confidence, flow, evidence `{type: screenshot|command,
   path, detail}`, fix, status) + health score per category and overall.
   Same finding shape as `guild-verdict.json`.
   → verify: `python3 -m json.tool <memory>/jobs/<slug>/reports/test-qa.json` parses;
   `test-qa.prev.json` exists, or there was no earlier run.

8. **Trend** — if `reports/test-qa.prev.json` exists, match fingerprints against it:
   Resolved / Persistent / New, and show the score change (before → now).
   → verify: the report has a trend section, or says "baseline run".

9. **Log** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append wield <slug> suite <PASS|FAIL|PARTIAL> jobs/<slug>/reports/test-qa.md`
   (FAIL = any Critical/High open; PARTIAL = some flows could not run).
   → verify: `ledger.sh tail 1` shows the line.

## Fixes

Fixes go to `/smithy:strike` (no plan needed), filtered by the tier. Hand
strike these rules: one commit per fix, message
`fix(qa): ISSUE-NNN — <desc>`; never bundle fixes; a fix that causes a
regression is reverted (a new revert commit) and the issue marked deferred.

## Done when

- [ ] the target, tier and flow list (with sources) are stated
- [ ] every flow ran, or is listed as not run with the reason
- [ ] UI runs: screenshots exist and each one is cited in the report
- [ ] every finding has severity + reason, confidence, fingerprint and evidence
- [ ] health score per category and overall; trend or "baseline run"
- [ ] `test-qa.md` and a parsing `test-qa.json` written
- [ ] ledger line written under `wield`

## Output

`jobs/<slug>/briefs/wield.md` · `jobs/<slug>/reports/test-qa.md` ·
`jobs/<slug>/reports/test-qa.json` · `jobs/<slug>/reports/qa-evidence/`.

`Next: /smithy:strike — fix the findings (score X/100)` · or `Next: /smithy:proof — load-test the service` · or `Next: none — QA clean`.

## Red flags

| Thought | Reality |
|---|---|
| "The API returned 200, the flow works" | Check what the user sees, not just the status code. |
| "Screenshots only when something fails" | Every flow gets one. No screenshots = invalid report. |
| "This flow isn't in the spec, but it should be" | Ask. Flows trace to the spec or the user. |
| "Small fix, I'll do it while I'm here" | QA reports. Fixes go through strike. |
