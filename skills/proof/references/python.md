# Proof Playbook — Python

## Tool: locust (headless)

Write a minimal `locustfile.py` in the job's reports dir (NOT the project
root) defining the flows as tasks, then:

```
uv run locust --headless -u <users> -r <spawn-rate> -t <time> -H <host> \
  -f docs/smithy/jobs/<slug>/reports/locustfile.py --csv docs/smithy/jobs/<slug>/reports/proof
```

(or `python3 -m locust ...` / `poetry run locust ...` per the project env;
if locust isn't available and can't be run ephemerally, ask before installing
— or fall back to autocannon via npx for plain HTTP endpoints.)

Read from the CSV/stdout: request count, failure count, median/p95/p99
response times, RPS. p99 + failure rate are the usual threshold columns.

## Phases

1. Warm-up: `-u 5 -t 10s` (discard).
2. Ramp: `-u 10`, `-u 25`, target.
3. Sustained: target users for the agreed duration.
4. Spike: 2× target, 15s; then one low-load recovery run.

## Rules

- In-process test clients are NOT valid for proof — load must cross the real
  server (uvicorn/gunicorn) the way production traffic would.
- Monitor the server process (memory growth, worker restarts) during runs.
- Local-only targets unless the user explicitly approved a host this session.
