# Proof Playbook — TypeScript/JavaScript

## Tool: autocannon (default — zero-install via npx)

```
npx autocannon -c <connections> -d <seconds> [-p <pipelining>] <url>
POST: npx autocannon -c 50 -d 60 -m POST -H 'content-type: application/json' -b '<json>' <url>
```

Read from output: `Latency` (avg/p50/p97.5/p99), `Req/Sec`, `2xx`/`non-2xx`
counts, errors/timeouts. p99 and non-2xx are the usual threshold columns.

## Tool: k6 (only if already installed in the project)

Script with `stages` for ramp/sustain/spike; thresholds block mirrors the
agreed SLOs (`http_req_duration: ['p(99)<500']`, `http_req_failed: ['rate==0']`).
Run: `k6 run script.js`.

## Phases

1. Warm-up: `-c 5 -d 10` (discard results — JIT/cache warm).
2. Ramp: repeat at c=10, 25, target. Record each.
3. Sustained: target c for the agreed duration.
4. Spike: 2× target c, 15s. Watch recovery afterward with one more low-load run.

## Rules

- Monitor the service process during runs (`ps`/memory via `/proc` or
  `process.memoryUsage` logs if the app exposes them) — note leaks/restarts.
- One variable at a time: never change route AND concurrency between runs.
- Local-only targets unless the user explicitly approved a host this session.
