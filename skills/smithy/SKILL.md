---
name: smithy
description: Run the full smithy dev pipeline (research → plan → implement → review → test) with approval gates between phases, resuming from project memory. Use when asked to "run smithy", "build this feature end to end", "full pipeline", "take this from idea to tested code", or to resume interrupted smithy work.
---

# Smithy — Pipeline Orchestrator

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/memory.md` first.
If `docs/smithy/` is missing, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.

**You orchestrate. You never do phase work yourself.** Each phase runs by
invoking that phase's skill; you read back only status lines, artifact paths,
and short summaries. Never paste artifact contents into your context.

## Entry: resume or start

1. Read `docs/smithy/STATE.md` and `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail 30`.
2. If STATE.md shows an active job, AskUserQuestion: **Resume** at the
   recorded phase (say exactly where: phase + unit) or **Start new** (the
   old job stays on disk) or **Abort old job**.
3. Resume rule: recompute position from the LEDGER, not recollection — the
   first unit without a `DONE`/`APPROVED`/`PASS` line is where work resumes.
   Cross-check `git log --oneline <base>..HEAD` when a base sha exists.

## State machine

```
ASSAY → [gate] → BLUEPRINT → [gate] → FORGE → TEMPER → [gate] → DONE
                                 ↕ on failure ↕
                                    ANNEAL (detour; returns to the phase that broke)
```

Phase → skill: ASSAY=`/smithy:assay`, BLUEPRINT=`/smithy:blueprint`,
FORGE=`/smithy:forge` (its per-task inspect verdicts are internal — no user
gate per task; two REJECTED cycles on one task escalates to the user),
TEMPER=`/smithy:temper`, ANNEAL=`/smithy:anneal`.

## Gates

At each `[gate]` (skipped only if `gates.pause_between_phases` is false in
the effective config):

1. Present: the phase's artifact path + a ≤5-line summary + what the next
   phase will do.
2. AskUserQuestion: **Approve** (continue) / **Revise** (re-run the phase
   with the user's feedback appended) / **Abort** (update STATE.md, stop).
3. Log: `ledger.sh append gate <slug> <phase> <APPROVED|REJECTED> <artifact>`
   and update STATE.md (phase, next step).

## Failure routing

- FORGE task fails verify or review twice → offer ANNEAL on the failing
  report before escalating further.
- TEMPER returns NOT READY → offer ANNEAL with the failing suite's report;
  after the fix, re-run ONLY the failing suite, then re-consolidate.
- ANNEAL exits → return to the exact unit that broke, not the phase start.

## Context discipline

- After each gate on large jobs, recommend the user `/clear` — the ledger
  and STATE.md carry everything forward; prove it by citing the resume rule.
- If you notice your context bloating mid-FORGE, say so and recommend
  clearing; resume is lossless by design.

## Exit

TEMPER verdict READY + final gate approved → update STATE.md
(Phase: IDLE, next step: none), then offer `/smithy:handover`.
