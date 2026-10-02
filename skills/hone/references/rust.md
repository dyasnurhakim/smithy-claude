# Hone Playbook — Rust

## Function benchmarks

- **criterion if it is already a dev-dependency** (`[[bench]]` targets /
  `benches/` folder): `cargo bench` — criterion handles warm-up, outliers
  and baseline comparison (`target/criterion/`) properly; quote its estimates.
- No criterion → `hyperfine` on a scratch binary if installed
  (`hyperfine --warmup 3 './target/release/bench_bin'`), else `time` on ≥3
  runs, median. Never add criterion to the project without asking.
- **Always `--release`.** A debug-build number is invalid anywhere in the report.

## CPU profiling

- `perf` + flamegraph if available:
  `perf record -g ./target/release/app ... && perf report --sort=dso,symbol`
  (or `cargo flamegraph` if installed). Save the files under `<reports>/perf/`.
- No perf → rough attribution: time variants of the operation that isolate
  the suspect path (feature flags, input shaping) and subtract the medians —
  label it "differential timing, not a profile".

## Memory

- RSS trend (memory in use) via `ps -o rss= -p <pid>` across N operations.
- Allocation counts: only if the repo already has an instrumented allocator
  (dhat, jemalloc stats) — do not add one uninvited.

## Server endpoints

Latency via autocannon at LOW concurrency (`-c 5`) against the release
binary. Report p50 (the headline) and p99.

## Rules

- Fixed inputs written in the brief; the same build profile for baseline and
  current (write down `cargo build --release` + the toolchain version).
- Wrap benchmarked values in `std::hint::black_box` in scratch benches —
  LLVM deletes work whose result is never used.
- Medians of ≥3 runs; flag >10% variance between runs.
