# Hone Playbook — TypeScript/JavaScript

## Micro/function benchmarks

- vitest bench if configured: `npx vitest bench --run`.
- Otherwise a scratch script with `node:perf_hooks` (`performance.now()`),
  ≥3 runs × ≥1000 iterations for sub-ms operations; report medians.

## CPU profiling

```
node --cpu-prof --cpu-prof-dir=docs/smithy/jobs/<slug>/reports/perf <entry.js>
```
Inspect the `.cpuprofile` hot functions (self time %). For TS, run the built
output or use tsx with the same flag.

## Server endpoints

Latency via autocannon (see proof playbook) at LOW concurrency (-c 5) — hone
measures speed, not load capacity. p50 is the honest headline; report p99 too.

## Memory

`process.memoryUsage()` sampled before/after N operations in a scratch
script; growth across GCs (`global.gc` with `--expose-gc`) signals leaks.

## Rules

- Fixed inputs, documented in the brief — comparisons must be like-for-like.
- Kill background noise: no dev server/watchers running during measurement.
- Medians, never single runs; note variance when runs disagree >10%.
