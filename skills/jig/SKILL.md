---
name: jig
description: "TDD: write failing tests first, then the code, then ONE clean commit per task — the test-first order is proven by snapshots, not extra commits. Triggers: 'jig', 'TDD this', 'test-first', bug fixes with a repro."
---

# Jig — Test-First Building

A jig holds the work piece so it comes out right. Here the tests are the
jig: they exist and fail BEFORE the code is written. This file is the ONE
place the TDD rules live — forge, dispatch and calibrate point here.

```
start ──▶ RED ─────────────▶ GREEN ─────────────▶ (REFACTOR) ──▶ ONE commit
picture   tests written,     code written,        tidy up         "feat: …"
          they fail          tests pass                           tests + code
    every arrow = `tdd-snap.sh take`; the pictures prove the order,
    so git history stays clean: one commit per task
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh jig new` — read its summary.
   (Standalone only: forge drives TDD itself and never runs jig's Start.)
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`.
3. Save the start sha: `git rev-parse HEAD` → write it down; the review uses it.

## When to use TDD

| Work | Use |
|---|---|
| Behavior you can state as tests (functions, APIs, parsers, rules) | **jig** |
| Bug fixes | **jig, always** — the failing test IS the bug reproduced |
| Visual or exploratory work (layout, design spikes) | plain forge, tests after with `/smithy:ring-test` |
| Config, docs, renames — nothing to assert | plain forge |

`implementation.tdd` in config: `always` = every forge task uses jig;
`never` = none; `ask` (default) = forge asks once per job.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| A brief with testable requirements | use it (`jobs/<slug>/briefs/task-N.md`) | write a mini brief from the user's request (template: `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3). Each requirement = observable behavior ("returns 400 when email is empty"). Show it; the user's OK is also the commit approval → `guard.sh grant <slug>` |
| Requirements that are testable | dispatch | rewrite them WITH the user — never guess. In a pipeline, name the problem and send it back to `/smithy:blueprint` |
| A test runner | `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh` finds it | ask the user for the test command |
| A clean working tree | continue | show `git status --short` and ask; never stash on your own |
| Commit approval | `guard.sh status` shows a grant | ask: "OK to commit this task?" → on yes, `guard.sh grant <slug>` |

## The three settings

Read all three in ONE call (merges defaults → global → project):

```bash
for k in tdd_level tdd_commits max_fix_cycles; do printf '%s=' $k; bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get implementation.$k; done
```

| Setting | Values | What it changes |
|---|---|---|
| `tdd_level` | `minimal` · `balanced` (default) · `max` | how many tests; at `max`, one requirement at a time |
| `tdd_commits` | `clean` (default) · `stages` | `clean` = one commit per task. `stages` = a commit per stage. Old names still work: `git` = stages, `local` = clean |
| `max_fix_cycles` | number, default 2 | fix rounds after the final review before asking the user |

Say the three values to the user in one line before the first dispatch.

## Brief lines (copy exactly — the agent sees the same words every time)

Add to the brief's `## Report` section, with `<root>` = `${CLAUDE_PLUGIN_ROOT}`
and `<unit>` = the brief's unit (`task-N`, or `fix-N` from anneal):

- Always:
  `TDD: write the failing tests FIRST, then the code. Prove the order with pictures: run "bash <root>/scripts/tdd-snap.sh start <slug> <unit>" before any test; "take <slug> <unit> RED '<n> of <m> failing: <first reason>' (n = failing, m = new tests; they must be equal)" when the new tests fail; "take <slug> <unit> GREEN '<suite summary>'" when they pass; "take <slug> <unit> REFACTOR" after any tidy-up; "verify <slug> <unit>" last — it must print OK.`
- Level (one of):
  - minimal: `TDD level: MINIMAL. Per requirement, ONE test: the main behavior, plus the one failure most likely to ship a bug. Write ALL the task's tests first, run them once (RED), then write the code (GREEN).`
  - balanced: `TDD level: BALANCED. Per requirement: the main behavior plus its realistic edge cases and error paths. No combinatorial lists. Write ALL the task's tests first, run them once (RED), then write the code (GREEN).`
  - max: `TDD level: MAX. Per requirement: main behavior, boundaries, error paths, invariants, hostile input. Work ONE requirement at a time: its tests (RED), its code (GREEN), then the next.`
- Commits (one of):
  - clean: `TDD commits: CLEAN. Make ONE commit at the end — tests and code together — with the brief's commit message. Never commit a single stage.`
  - stages: `TDD commits: STAGES. Commit each stage: "test: … (RED)", then "feat:/fix: … (GREEN)", then "refactor: …" if any. Still take every picture.`
- If a stack playbook exists (`${CLAUDE_PLUGIN_ROOT}/skills/ring-test/references/<stack>.md`), add its path as the test style guide.

## Steps

1. **Settings** — read the three settings (one call above); say them in one line.
   If `tdd_commits` printed the note that `local` is an old name: tell the
   user once that `local` (no commits) now means `clean` (ONE commit per
   task), and ask before the first commit (they may want `stages`, or to stop).
   → verify: three `key=value` lines printed.
2. **Brief** — ready per **Needs**; add the brief lines above.
   → verify: every requirement is observable behavior; the TDD, level and commits lines are present.
3. **Lookup** (creed §10, once) — memory: past bugs/decisions on the brief's
   files; graph: callers of what will change. Put what matters in `key_facts`.
   → verify: `key_facts` has sources, or says `[]`.
4. **Dispatch** the `jigsmith` per `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §1–2 (role
   `implementation`; prompt = banner + paths + "Job <slug>, task N").
   → verify: the agent returned a status.
5. **Handle the status** (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §4).
   → verify: status is DONE, or the next action for it is taken (answer, fix, or ask the user).
6. **Check the proof yourself** — do not trust the report:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/tdd-snap.sh verify <slug> task-N`
   - `OK` and status DONE → done; read the report only if there are `WARN:` lines.
   - `FAIL` → re-dispatch once with the FAIL line added to the brief; a second FAIL → the user.
   - `stages` mode only: also `git log --oneline <start-sha>..HEAD` — each `test:` comes before its `feat:`/`fix:`.
   - clean mode: `git log --oneline <start-sha>..HEAD` shows exactly ONE commit for the task.
   - Read the RED line(s) of the log (`grep '| RED |' <log>`): the note must
     name a missing behavior ("not a function", an assertion that failed),
     not a syntax, import-path or setup error. Otherwise treat it like a FAIL.
   - Every new test failed: the note's `<n> of <m>` must have n = m. A new
     test that passes at RED proves nothing (e.g. a "throws TypeError" test
     passes when the function does not exist yet, because calling undefined
     also throws TypeError). n < m → re-dispatch: that test must be made to
     fail for the missing behavior first.
   - The number of tests fits the level (minimal ≈ one per requirement;
     max = many). Far off → re-dispatch with the level restated.
   → verify: `tdd-verify: OK` line, the commit count matches the mode, and the RED notes pass both checks.
7. **Review** — run by jig only when it was called on its own (forge runs one
   review for the whole job). One inspector over the task, per
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §5, with `--base <start sha>`. Tell it the TDD
   commits mode. Fix rounds: `implementation.max_fix_cycles` (§6).
   → verify: both verdicts APPROVED, or the user decided.
8. **Log** — `ledger.sh append jig <slug> task-N <STATUS> <report>`; update
   STATE.md. On its own, write `jobs/<slug>/reports/forge-report.md` (one-task form, `/smithy:forge` § forge-report.md).
   → verify: the ledger line is written; standalone, `forge-report.md` exists.

## Done when

- [ ] the three settings were stated to the user
- [ ] every requirement in the brief is observable behavior
- [ ] `tdd-snap.sh verify` printed `OK` for every task (paste the line)
- [ ] commit count matches the mode (clean = one per task)
- [ ] full test suite green in the agent's report (paste the summary line)
- [ ] review APPROVED (standalone) or handed back to forge (pipeline)
- [ ] ledger lines written; STATE.md updated

## Output

`jobs/<slug>/reports/forge-report.md` (standalone) · `jobs/<slug>/reports/raw/task-N-tdd.log` (the pictures log).

`Next: /smithy:temper — run the full test pass` (standalone) — or return to forge.

## Red flags

| Thought | Reality |
|---|---|
| "I'll write the code first, tests right after" | Tests written after pass by design and prove nothing. `verify` will FAIL it. |
| "The test obviously fails, skip running it" | An unrun RED is no proof the test can fail. Run it, then `take RED`. |
| "MINIMAL means I can skip RED" | MINIMAL cuts the NUMBER of tests, never the order. |
| "I'll commit the RED stage, just to be safe" | In clean mode that dirties history. The picture is the proof. |
| "verify said FAIL but the report reads fine" | The pictures are the evidence; the report is a claim. FAIL wins. |
| "The requirement isn't testable, I'll approximate" | NEEDS_CONTEXT. Fix the brief with the user. |
