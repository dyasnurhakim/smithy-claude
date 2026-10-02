---
name: hone
description: "Performance: measure a baseline first, at least 3 runs and the median, find hot spots with profiler proof, give recommendations only (never edits code). Works inside a job or on its own. Triggers: 'hone', 'why is it slow', 'benchmark'."
---

# Hone — Performance

Honing sharpens an edge a little at a time, and you check after each pass.
Here: measure first, profile to find where time goes, then recommend.

```
baseline? ─▶ ≥3 runs per target ─▶ MEDIAN ─▶ compare with last run ─▶ profile top-3 hot spots ─▶ recommendations
 (none = this run IS the baseline)            (>10% on a stable median = regression)            (hone never edits code)
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh hone auto` — read its summary.
   Called by temper: `start.sh hone <temper's slug>` so both log to the same job.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| What to measure | the operations the job's `spec.md` / `plan.md` touched | ask: "which operation feels slow?" Each target must be a concrete command or call, not a feeling |
| A baseline | this job's earlier `jobs/<slug>/reports/test-perf.md`, else the newest `jobs/*/reports/test-perf.md` (by mtime) from earlier jobs → step 3 copies it to `reports/test-perf.prev.md` and this run compares to it | this run IS the baseline — say so. A first run gives numbers, not verdicts |
| Tools | `stack-detect.sh` finds the stack | `stack=unknown` → `time` on repeated runs, median of ≥3 |

## Steps

1. **Pick the tools** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh`;
   pick the playbook by `stack=`: `${CLAUDE_PLUGIN_ROOT}/skills/hone/references/ts.md`,
   `python.md`, `go.md`, `java.md`, `rust.md` (TS/JS `node --cpu-prof` /
   vitest bench; Python cProfile / pytest-benchmark; Go `go test -bench` +
   pprof; Java JMH or JFR; Rust criterion / perf, always `--release`).
   → verify: playbook path and the bench + profile commands are named.

2. **Lookup** (creed §10, optional, once) — memory: earlier perf numbers or
   decisions on these paths; docs: the profiler's flags for the pinned
   version. Put what matters in the brief's `key_facts`, with its source.
   → verify: `key_facts` filled with sources, or `[]`.

3. **Write the brief** — first keep the baseline: copy the earlier
   `test-perf.md` (Needs → A baseline) to `jobs/<slug>/reports/test-perf.prev.md`
   before the run overwrites it. Then write `jobs/<slug>/briefs/hone.md`
   (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §3): the baseline (`reports/test-perf.prev.md`,
   or "none — this run is the baseline"), targets, exact tool commands, **≥3 runs per measurement, report the
   MEDIAN** (one run is noise), fixed inputs written down (so the next run
   compares like with like), report path `jobs/<slug>/reports/test-perf.md`,
   profiles saved under `jobs/<slug>/reports/perf/`. No `## Persona` (the
   playbooks carry the rules).
   → verify: the brief names the baseline (or "none"), the targets, the inputs, the run count and the report path.

4. **Dispatch** one `temperer` (role `testing`; `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
   §1–2: banner + paths + "Job <slug>, hone"). Every number in the report
   must appear in tool output.
   → verify: the report exists; profiles are in `reports/perf/`.

5. **Read the report** — a table `operation | baseline | current | change`.
   Top 3 hot spots ranked by measured cost, each with profiler proof
   (function, `file:line`, % of time). Regression = a change beyond noise
   (rule of thumb: >10% on a stable median).
   → verify: every row has a median from ≥3 runs; every hot spot has profiler proof.

6. **Recommend — never edit.** Each recommendation: the hot spot, the
   proposed change, the expected direction of the gain, and its risk.
   Small, known changes → `/smithy:strike`; bigger or structural changes →
   `/smithy:blueprint`.
   → verify: `git status --short` shows no production code changed by this run.

7. **Log** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append hone <slug> suite <PASS|FAIL|PARTIAL> jobs/<slug>/reports/test-perf.md`.
   FAIL only when a regression against the baseline is beyond the noise
   rule. A first (baseline) run logs PASS — there is nothing to regress against.
   → verify: `ledger.sh tail 1` shows the line.

## Done when

- [ ] baseline status stated: compared to `<file>`, or "this run is the baseline"
- [ ] every target measured ≥3 times; the median is reported, with fixed inputs written down
- [ ] top hot spots have profiler proof (`file:line`, % of time)
- [ ] every number appears in tool output
- [ ] recommendations only — no production code changed
- [ ] ledger line written under `hone`

## Output

`jobs/<slug>/briefs/hone.md` · `jobs/<slug>/reports/test-perf.md` · `jobs/<slug>/reports/perf/`.

`Next: /smithy:strike — apply the small recommendations` · or `Next: /smithy:blueprint — plan the structural ones` · or `Next: none — no regression`.

## Red flags

| Thought | Reality |
|---|---|
| "One run is clearly faster" | One run is noise. ≥3 runs, the median. |
| "I see the fix, I'll just make it" | Hone recommends. Changes go through strike or blueprint. |
| "First run is slow — that's a regression" | A first run is the baseline. Nothing to regress against. |
