# Proof Playbook — Rust

## Load client (any language)

Default: `npx autocannon -c <conns> -d <secs> <url>`. Use `wrk` / `hey` /
`k6` / `oha` ONLY if already installed — never install load tools into the
user's project.

## The target under load — release build, always

- **`cargo build --release` and run the release binary.** Debug builds are
  10–100× slower; a number from a debug build is invalid and must not appear
  in the report. Write down the exact binary path and build profile.
- Readiness: poll the health/root endpoint before warm-up.

## What to watch during runs (Rust)

- Watch RSS (memory in use: `ps -o rss= -p <pid>`) before / during sustained
  load / after the spike. A Rust service should hold RSS nearly flat —
  steady growth = a leak finding (usually unbounded channels, caches, or
  Arc cycles).
- Capture stderr for the whole run: any `thread '...' panicked` under load
  is a Critical finding even if the service stays up (panics in worker
  tasks often show only as latency spikes).
- Open files under the spike: `ls /proc/<pid>/fd | wc -l` at the three
  check points — a growing count = a connection leak.
- Tokio runtimes: if the app already exposes metrics (tokio-console, a
  prometheus endpoint), read blocked tasks / queue depth there; do not add
  instrumentation without asking.

## Phases

Warm-up `-c 5 -d 10` (warms the allocator and pools; throw away) → ramp →
sustained → spike (2×, 15s) → low-load recovery run; RSS and open-file
counts should be back to baseline within seconds.
