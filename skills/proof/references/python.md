# Proof Playbook — Python

## Tool: locust (headless)

Write a small `locustfile.py` in the job's reports folder (NOT the project
root) with the flows as tasks, then:

```
uv run locust --headless -u <users> -r <spawn-rate> -t <time> -H <host> \
  -f $SMITHY_MEM/jobs/<slug>/reports/locustfile.py --csv $SMITHY_MEM/jobs/<slug>/reports/proof
```

(or `python3 -m locust ...` / `poetry run locust ...` per the project env.
If locust is not available and cannot run one-off, ask before installing —
or use autocannon via npx for plain HTTP endpoints.)

Read from the CSV / stdout: request count, failure count, median/p95/p99
response times, RPS. p99 and the failure rate are the usual limit columns.

## Phases

1. Warm-up: `-u 5 -t 10s` (throw away).
2. Ramp: `-u 10`, `-u 25`, target.
3. Sustained: target users for the agreed duration.
4. Spike: 2× target, 15s; then one low-load recovery run.

## Rules

- In-process test clients do NOT count for proof — the load must go through
  the real server (uvicorn/gunicorn), the way production traffic does.
- Watch the server process (memory growth, worker restarts) during runs.
- Local targets only, unless the user approved a host this session.
