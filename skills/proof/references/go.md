# Proof Playbook — Go

## Load client (any language)

The load tool does not care that the target is Go. Default:
`npx autocannon -c <conns> -d <secs> <url>` (see the notes in ts.md).
Use `hey`, `vegeta`, `wrk` or `k6` ONLY if already installed — never
install load tools into the user's project.

## The target under load — build and run it right

- Load-test the **release build**: `go build -o app ./cmd/... && ./app` —
  never `go run` (compile time pollutes the numbers) and never a `-race`
  build (it is many times slower, so every number would be wrong).
- Readiness: poll the health/root endpoint before the warm-up phase.

## What to watch during runs (Go)

- If the app already exposes `net/http/pprof` (or you may add it behind a
  scratch flag — ask first): capture `/debug/pprof/goroutine?debug=1` counts
  before / during sustained load / after the spike. **Goroutine counts that
  keep growing after load stops = a leak = a FAIL-worthy finding**, whatever
  the latency.
- Watch RSS (memory in use: `ps -o rss= -p <pid>`) at the same three points;
  report the trend.
- `GOMAXPROCS` and container CPU limits change the results — write `nproc`
  and any limits in the report.

## Phases

Warm-up (no JIT in Go, but caches and pools warm up): `-c 5 -d 10`, throw
the numbers away. Then ramp → sustained → spike per the brief, and one
low-load recovery run at the end — a Go service should be back to its
baseline goroutines/RSS within seconds.
