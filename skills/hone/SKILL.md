---
name: hone
description: Profile and benchmark hot paths, find regressions against a baseline, recommend targeted optimizations. Use when asked to "hone", "profile this", "why is it slow", "benchmark", or as part of /smithy:temper.
---

# Hone — Performance

(Honing sharpens the edge — measured, incremental, never blind.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append temper <slug> hone STARTED -`

## Process

1. **Baseline first.** If a prior `reports/test-perf.md` exists, this run
   diffs against it. If not, this run IS the baseline — say so; a first run
   produces numbers, not verdicts (nothing to regress against).

2. **Determine what to measure.** Pipeline mode: the operations the job's
   spec/plan touched. Standalone: ask ("which operation feels slow?").
   Every measurement target is a concrete invocation, not a vibe.

3. **Detect tooling** (stacks.md): TS/JS → `node --cpu-prof` + vitest bench
   where configured; Python → cProfile + pytest-benchmark if present.
   Fallback: `time` on repeated invocations.

4. **Write the test brief** (`briefs/hone.md`): targets, tool invocations,
   **≥3 runs per measurement, report the MEDIAN** (single runs are noise),
   fixed inputs (document them so the next run compares like-for-like),
   report path `reports/test-perf.md`.

5. **Dispatch `smithy:tester`** (routing role `testing`). Every number in the
   report must appear in tool output; profiles saved under `reports/perf/`.

6. **Read the report.** Table: operation | baseline | current | delta.
   Top-3 hot spots ranked by measured cost, each with profiler evidence
   (function, file:line, % of time). Regression = delta beyond noise
   (rule of thumb: >10% on a stable median).

7. **Recommendations only.** Each: the hot spot, the proposed change, the
   expected direction of impact, and its risk. Edits go through
   `/smithy:blueprint` (structural) or `/smithy:forge` (surgical) — hone
   never edits source.

8. **Log:** `ledger.sh append temper <slug> hone <PASS|FAIL|PARTIAL> reports/test-perf.md`
   (FAIL only when a regression against baseline exceeds the noise rule; a
   first baseline run logs PASS — there is nothing to regress against).

Handoff: "Optimizations → `/smithy:forge` (surgical) or `/smithy:blueprint` (structural)."
