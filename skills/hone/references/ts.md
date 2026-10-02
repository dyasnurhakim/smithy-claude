# Hone Playbook — TypeScript/JavaScript

## Function benchmarks

- vitest bench if set up: `npx vitest bench --run`.
- Otherwise a scratch script with `node:perf_hooks` (`performance.now()`):
  ≥3 runs × ≥1000 iterations for operations under 1ms; report medians.

## CPU profiling

```
node --cpu-prof --cpu-prof-dir=$SMITHY_MEM/jobs/<slug>/reports/perf <entry.js>
```
Read the hot functions (self time %) from the `.cpuprofile`. For TS, run the
built output, or use tsx with the same flag.

## Server endpoints

Latency via autocannon (see the proof playbook) at LOW concurrency (-c 5) —
hone measures speed, not load capacity. p50 is the honest headline; report p99 too.

## Memory

Sample `process.memoryUsage()` before/after N operations in a scratch
script; memory that keeps growing across GCs (`global.gc` with
`--expose-gc`) points to a leak.

## Rules

- Fixed inputs, written in the brief — compare like with like.
- Cut background noise: no dev server or watchers running while you measure.
- Medians, never single runs; note the variance when runs differ by >10%.
