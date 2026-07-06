# Proof Playbook — Rust

## Load client (language-agnostic)

Default: `npx autocannon -c <conns> -d <secs> <url>`. Prefer `wrk`/`hey`/
`k6`/`oha` ONLY if already installed — never install load tools into the
user's project.

## Target under load — release build is non-negotiable

- **`cargo build --release` and run the release binary.** Debug builds are
  10–100× slower; any number from a debug build is invalid and the report
  must not contain one. Record the exact binary path and build profile.
- Readiness: poll the health/root endpoint before warm-up.

## Rust-specific monitoring during runs

- Watch RSS (`ps -o rss= -p <pid>`) before / during-sustained / after-spike;
  Rust services should hold near-flat RSS — steady growth = leak finding
  (usually unbounded channels, caches, or Arc cycles).
- Capture stderr for the whole run: any `thread '...' panicked` under load is
  a Critical finding even if the service stays up (panics in worker tasks
  often surface only as latency spikes).
- File descriptors under spike: `ls /proc/<pid>/fd | wc -l` at the three
  checkpoints — fd growth = connection leak.
- Tokio runtimes: if the app already exposes metrics (tokio-console,
  prometheus endpoint), read blocked-task/queue-depth there; do not add
  instrumentation without asking.

## Phases

Warm-up `-c 5 -d 10` (allocator/pool warm, discard) → ramp → sustained →
spike (2×, 15s) → low-load recovery run; RSS and fd counts should return to
baseline within seconds.
