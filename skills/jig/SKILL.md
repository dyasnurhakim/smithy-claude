---
name: jig
description: Test-driven implementation — the TDD path through smithy. Runs a task (or whole plan) RED→GREEN→REFACTOR via the jigsmith agent, with verbatim failing-test evidence per requirement. Use when asked to "jig", "TDD this", "test-first", "test-driven", or when forge's TDD mode is on.
---

# Jig — Test-Driven Implementation

(A jig is the guide that constrains the workpiece so it comes out right.
Tests written first are the jig; the implementation is shaped against them.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append forge <slug> jig STARTED -`

## When jig vs plain forge

| Situation | Path |
|---|---|
| Behavior is specifiable as tests up front (functions, APIs, parsers, business logic) | **jig** — TDD pays for itself |
| Exploratory/visual work where the assertion isn't knowable first (UI layout, design spikes) | plain forge, tests after via `/smithy:ring-test` |
| Bug fixes | **jig always** — the regression test IS the failing test (RED = reproduce) |
| Config/docs/mechanical changes with nothing to assert | plain forge |

The choice is per-job (or per-task when tasks differ in nature). It is
controlled by `implementation.tdd` in the effective config:
- `"always"` — every forge task dispatches the jigsmith
- `"never"` — every forge task dispatches the plain forger
- `"ask"` (default) — forge asks the user ONCE per job, at the first task,
  with a recommendation derived from the table above

## Requirements for TDD-ready briefs

A brief the jigsmith can execute must have **testable requirements** — each
one phrased as observable behavior ("returns X when Y", "exits 64 on any
argument"), not implementation instructions ("add an if statement"). If a
brief's requirements are not testable as written:
- pipeline mode → send it back to `/smithy:blueprint` with the specific
  problem named;
- standalone → rewrite the requirement WITH the user before dispatching.
The jigsmith will return NEEDS_CONTEXT on untestable requirements — that is
the system working, not a failure.

## Process (per task)

1. **Resolve routing:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh implementation`

2. **Record base:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh record-base`

3. **Augment the brief.** Add to the brief's Report section:
   `TDD mode: write the failing test FIRST for each requirement (RED), then
   the minimal implementation (GREEN), commit per stage.` If the project has
   a stack playbook (`${CLAUDE_PLUGIN_ROOT}/skills/ring-test/references/`
   `{ts,python,go,java,rust}.md` per stack-detect), add its path as the
   test-convention reference.

4. **Dispatch the `smithy:jigsmith` agent** (model from routing; effort
   banner; paths only: brief, creed, report path).

5. **Verify the TDD evidence.** Read the report. For EACH requirement check:
   - RED shows a real behavioral failure (not an import error),
   - GREEN shows the same test passing,
   - the commit list shows test-before-implementation ordering
     (`git log --oneline <base>..HEAD` — `test:` commits precede their
     `feat:`/`fix:` commits per requirement).
   Missing/faked evidence → REJECTED: re-dispatch once with the gap named,
   then escalate to the user.

6. **Review.** Build the package and dispatch the inspector exactly as
   `/smithy:forge` step 5 does — TDD does not skip review. The inspector
   additionally verifies the commit ordering claim.

7. **Log:** `ledger.sh append forge <slug> task-N <STATUS> <report>` plus the
   inspect verdict line, and update STATE.md.

## Red flags — stop and restart the loop

| Thought | Reality |
|---|---|
| "I'll implement first and add tests after — same thing" | It is not. Tests-after pass by construction; they prove nothing about RED. |
| "The test is trivial, skip running the failing state" | Unrun RED = no evidence the test can fail. Run it. |
| "One big test for all requirements is faster" | One behavior per test — otherwise GREEN can't localize what broke. |
| "This requirement isn't testable, I'll approximate" | NEEDS_CONTEXT. Untestable requirements are a brief defect, not yours to paper over. |

Handoff: same as forge — all tasks DONE + APPROVED → "run `/smithy:temper`."
