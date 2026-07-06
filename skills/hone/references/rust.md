# Hone Playbook — Rust

## Micro/function benchmarks

- **criterion if it's already a dev-dependency** (`[[bench]]` targets /
  `benches/` dir): `cargo bench` — criterion does warm-up, outlier rejection,
  and baseline comparison (`target/criterion/`) properly; cite its estimates.
- No criterion → `hyperfine` on a scratch binary if installed
  (`hyperfine --warmup 3 './target/release/bench_bin'`), else `time` on ≥3
  runs, median. Never add criterion to the project without asking.
- **Always `--release`.** A debug-build number is invalid anywhere in the
  report.

## CPU profiling

- `perf` + flamegraph if available:
  `perf record -g ./target/release/app ... && perf report --sort=dso,symbol`
  (or `cargo flamegraph` if installed). Save artifacts under
  `<reports>/perf/`.
- No perf → coarse attribution: time operation variants that isolate the
  suspect path (feature flags, input shaping) and difference the medians —
  label it "differential timing, not a profile".

## Memory

- RSS trend via `ps -o rss= -p <pid>` across N operations.
- Allocation counts: only if the repo already wires an instrumented allocator
  (dhat, jemalloc stats) — don't introduce one uninvited.

## Server endpoints

Latency via autocannon at LOW concurrency (`-c 5`) against the release
binary. Report p50 (headline) and p99.

## Rules

- Fixed inputs documented in the brief; identical build profile between
  baseline and current (record `cargo build --release` + toolchain version).
- `std::hint::black_box` around benchmarked values in scratch benches — LLVM
  deletes unobserved work.
- Medians of ≥3 runs; flag >10% variance between runs.
