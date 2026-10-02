---
name: ring-test
description: "Unit tests for the changed code, per the stack playbook: write the missing ones, run them, flag flaky ones. Works inside a job or on its own. Triggers: 'ring-test', 'unit test this', 'write unit tests'."
---

# Ring-Test — Unit Tests

A ring test taps each piece of metal and listens for cracks. Here: one
small test per behavior, run, and checked for flakes.

```
scope (plan / base / ask) ─▶ stack playbook ─▶ temperer: write + run + rerun ─▶ test-unit.md
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh ring-test auto` — read its summary.
   Called by temper: `start.sh ring-test <temper's slug>` so both log to the same job.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| Scope (what to test) | 1st: the tasks in `jobs/<slug>/plan.md` and the behaviors its success criteria name | 2nd: the job base in STATE.md → the code changed `<base>..HEAD`. 3rd: ask the user; recommend the changes since the merge-base with the default branch (`git merge-base HEAD origin/main`). Never stop for a missing STATE |
| A test runner | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh` finds it | `stack=unknown` → use the general rules in `${CLAUDE_PLUGIN_ROOT}/references/stacks.md` and confirm the test command with the user first |
| One stack | one `stack=` value | `also=` in the output (mixed repo) → ask which stack this job targets |

## Steps

1. **Pick the playbook** — run `stack-detect.sh`; pick this skill's
   playbook by `stack=`: `${CLAUDE_PLUGIN_ROOT}/skills/ring-test/references/ts.md` (js/ts),
   `python.md`, `go.md`, `java.md`, `rust.md`. Prefer the project's own test
   script (`package.json`, Makefile, CI) over a bare runner call.
   → verify: you can name the playbook path and the exact test command.

2. **Set the scope** (Needs, in that order) and list the behaviors to cover:
   happy path, edge values, error path — per the playbook's "What to cover".
   → verify: a list of target files + behaviors, and where the scope came from (plan / base / user).

3. **Lookup** (creed §10, optional, once) — graph: callers of the target code
   that no test reaches; memory: tests that were flaky here before. Put what
   matters in the brief's `key_facts`, with its source.
   → verify: `key_facts` filled with sources, or `[]`.

4. **Write the brief** `jobs/<slug>/briefs/ring-test.md` (template:
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3): playbook path, target files, behaviors, the
   test command, report path `jobs/<slug>/reports/test-unit.md`. Requirements:
   one behavior per test; Arrange-Act-Assert; names that say the behavior;
   no "snapshot everything"; never touch production code.
   `## Persona`: `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/qa.md` (test lens).
   → verify: the brief exists and names the playbook, the command and the report path.

5. **Dispatch** one `temperer` (role `testing`; `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
   §1–2: banner + paths + "Job <slug>, ring-test").
   → verify: the report exists; read its status with `envelope.sh get <report> status`.

6. **Read the report** —
   - FLAKY tests are failures (the same code gives different results). List
     them; never average them away.
   - A test that needs a code change to pass → known cause: `/smithy:strike`;
     unexpected failure: `/smithy:anneal`. The temperer never fixes code.
   → verify: `git status --short` shows only test files, fixtures or test config changed.

7. **Log** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append ring-test <slug> suite <PASS|FAIL|PARTIAL> jobs/<slug>/reports/test-unit.md`.
   → verify: `ledger.sh tail 1` shows the line.

## Done when

- [ ] the scope and its source (plan / base / user) are stated
- [ ] the suite ran — the test command and its summary line are in the report
- [ ] every behavior in scope has a test, or is listed as a gap
- [ ] every failure has a repro command; flaky tests are listed as FLAKY
- [ ] no production file changed (`git status --short`)
- [ ] ledger line written under `ring-test`

## Output

`jobs/<slug>/briefs/ring-test.md` · `jobs/<slug>/reports/test-unit.md`.

`Next: /smithy:wield — QA it the way a user would` · or, on FAIL: `Next: /smithy:anneal — find why the tests fail`.

## Red flags

| Thought | Reality |
|---|---|
| "It passed on the rerun, so it passes" | Pass-on-rerun is FLAKY. That is a finding. |
| "One small source fix makes the test pass" | Code fixes go through strike or anneal, so they get checked too. |
| "No plan, no STATE — I can't scope this" | Ask the user. Recommend the merge-base diff. |
