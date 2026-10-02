# Hone Playbook — Go

## Function benchmarks

- Go has benchmarks built in: `func BenchmarkX(b *testing.B)` next to the
  code, run with
  `go test -bench 'BenchmarkX' -benchmem -count=6 ./pkg | tee <reports>/bench.txt`.
- `-count=6` gives enough samples for benchstat; if `benchstat` is installed,
  compare baseline vs current with it (it does the noise math properly);
  else report the median of the 6 and the spread.
- Always `-benchmem`: a rise in allocs/op predicts production pain better
  than ns/op alone.

## CPU / memory profiling

```
go test -bench 'BenchmarkX' -cpuprofile=<reports>/perf/cpu.out -memprofile=<reports>/perf/mem.out ./pkg
go tool pprof -top -nodecount=15 cpu.out     # hottest functions by flat%
go tool pprof -top -sample_index=alloc_space mem.out
```
For a running service that already exposes pprof:
`go tool pprof -top 'http://host/debug/pprof/profile?seconds=30'`.

## Server endpoints

Latency via autocannon at LOW concurrency (`-c 5`) against the **release
build** — hone measures speed, not capacity. Report p50 (the headline) and p99.

## Rules

- Benchmark the built code, never `go run`; stop watchers and daemons first.
- Fixed inputs, written in the brief; `b.ResetTimer()` after costly setup.
- The compiler may delete work whose result is unused: store results in a
  package-level var in benchmarks, or you may measure nothing.
