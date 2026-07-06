# Proof Playbook — Go

## Load client (language-agnostic)

The load generator doesn't care that the target is Go. Default:
`npx autocannon -c <conns> -d <secs> <url>` (see the ts.md invocation notes).
Prefer `hey`, `vegeta`, `wrk`, or `k6` ONLY if already installed — never
install load tools into the user's project.

## Target under load — build and run it right

- Load-test the **release build**: `go build -o app ./cmd/... && ./app` —
  never `go run` (compilation noise) and never a `-race` build (order-of-
  magnitude slowdown invalidates every number).
- Readiness: poll the health/root endpoint before the warm-up phase.

## Go-specific monitoring during runs

- If the app already exposes `net/http/pprof` (or you may add it behind a
  scratch flag — ask first): capture `/debug/pprof/goroutine?debug=1` counts
  before / during-sustained / after-spike. **Monotonically growing goroutine
  counts after load stops = leak = FAIL-worthy finding** regardless of latency.
- Watch RSS (`ps -o rss= -p <pid>`) at the same three points; report the trend.
- `GOMAXPROCS`/container CPU limits skew results — record `nproc` and any
  limits in the report.

## Phases

Warm-up (JIT-irrelevant but cache/pool warm): `-c 5 -d 10`, discard. Then
ramp → sustained → spike per the brief; one low-load recovery run at the end —
Go services should return to baseline goroutines/RSS within seconds.
