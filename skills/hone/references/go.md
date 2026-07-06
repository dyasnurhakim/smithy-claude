# Hone Playbook — Go

## Micro/function benchmarks

- Native benchmarks are first-class: `func BenchmarkX(b *testing.B)` next to
  the code, run with
  `go test -bench 'BenchmarkX' -benchmem -count=6 ./pkg | tee <reports>/bench.txt`.
- `-count=6` gives benchstat-grade samples; if `benchstat` is installed,
  compare baseline vs current with it (it does the noise math properly);
  else report the median of the 6 and the spread.
- `-benchmem` always: allocs/op regressions predict production pain better
  than ns/op alone.

## CPU / memory profiling

```
go test -bench 'BenchmarkX' -cpuprofile=<reports>/perf/cpu.out -memprofile=<reports>/perf/mem.out ./pkg
go tool pprof -top -nodecount=15 cpu.out     # hot functions by flat%
go tool pprof -top -sample_index=alloc_space mem.out
```
For a running service that already exposes pprof:
`go tool pprof -top 'http://host/debug/pprof/profile?seconds=30'`.

## Server endpoints

Latency via autocannon at LOW concurrency (`-c 5`) against the **release
build** — hone measures speed, not capacity. Report p50 (headline) and p99.

## Rules

- Benchmark the built code, never `go run`; kill watchers/daemons first.
- Fixed inputs documented in the brief; `b.ResetTimer()` after expensive setup.
- Beware compiler elision: sink results to a package-level var in benchmarks,
  or the optimizer may delete the work you think you're measuring.
