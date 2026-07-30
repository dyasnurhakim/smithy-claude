---
name: jig
description: "TDD implementation: RED→GREEN→REFACTOR per requirement with verbatim failing-test evidence. Triggers: 'jig', 'TDD this', 'test-first', bug fixes."
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

## The three TDD dials

Read all three with `config.sh get` (it merges defaults → global → project;
reading a config file directly silently misses the user's global default):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get implementation.tdd_level
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get implementation.tdd_commits
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get implementation.max_fix_cycles
```

| Key | Values | What it buys |
|---|---|---|
| `tdd_level` | `minimal` \| `balanced` (default) \| `max` | Test breadth per requirement. `minimal` = one test, primary behaviour + the likeliest bug — "as long as the software works". `balanced` = + realistic edge/error paths. `max` = exhaustive, boundaries and adversarial cases included. |
| `tdd_commits` | `git` (default) \| `local` | `git` commits each RED/GREEN/REFACTOR stage. `local` commits nothing — the jigsmith keeps a stage log and leaves everything in the working tree. |
| `max_fix_cycles` | int, default `2` | How many review→fix re-dispatches a task gets before you stop and escalate. Applies to the plain forger too. |

The exact brief lines for each value live in `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
§4b — copy them verbatim rather than paraphrasing, so the agent sees the same
wording every time.

**`local` mode has a real cost — state it once when it is in play.** Commit
ordering from `git log` is the only piece of TDD evidence the controller does
not have to take on trust. In `local` mode there are no commits, so verification
falls back to the agent's own stage log and report. That is a legitimate choice
(no history noise, no commit grant needed, scratch worktrees) — but say so
plainly the first time it applies, then proceed without relitigating it.

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
   the minimal implementation (GREEN).` Then add the `TDD level:` and
   `TDD commits:` lines for the resolved values, copied verbatim from
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §4b. In `local` mode also
   name the stage-log path:
   `$SMITHY_MEM/jobs/<slug>/reports/raw/task-N-tdd-stages.md` (create the
   `raw/` dir first). If the project has a stack playbook
   (`${CLAUDE_PLUGIN_ROOT}/skills/ring-test/references/{ts,python,go,java,rust}.md`
   per stack-detect), add its path as the test-convention reference.

4. **Dispatch the `smithy:jigsmith` agent** (model from routing; effort
   banner; paths only: brief, creed, report path).

5. **Verify the TDD evidence.** Read the report. For EACH requirement check:
   - RED shows a real behavioral failure (not an import error),
   - GREEN shows the same test passing,
   - the ordering is test-before-implementation, verified per commits mode:

   | mode | how you verify ordering |
   |---|---|
   | `git` | `git log --oneline <base>..HEAD` — each `test:` commit precedes its `feat:`/`fix:` commit. Independent of what the report claims. |
   | `local` | Read the stage log: RED lines precede their GREEN lines per requirement, and its timestamps are monotonic. Cross-check every logged file against `git diff` / `git status` in the working tree — a stage log naming files the tree does not show is fabricated. Nothing may be committed; if commits exist, the agent violated the mode — treat it as REJECTED. |

   Also check the report's **Coverage at this level** line against the level
   you set: a `minimal` run listing twenty tests, or a `max` run listing one,
   means the dial was ignored — re-dispatch with the level restated.

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
| "`minimal` level means I can skip RED on the easy ones" | `minimal` cuts test COUNT, never the ordering. One honest failing test per requirement, always. |
| "`local` mode, but I'll commit at the end to be safe" | That is `git` mode with extra steps, and it puts commits in a history the user asked to keep clean. Leave it in the tree. |
| "The stage log is missing; the report reads convincingly" | In `local` mode the log IS the ordering evidence. No log = unverifiable = REJECTED. |

Handoff: same as forge — all tasks DONE + APPROVED → "run `/smithy:temper`."
