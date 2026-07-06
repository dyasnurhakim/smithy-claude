# Hone Playbook — Python

## Micro/function benchmarks

- pytest-benchmark if present: `uv run pytest --benchmark-only`.
- Otherwise `timeit` in a scratch script: ≥3 repeats
  (`timeit.repeat(..., repeat=3)`), report the MEDIAN of the repeats.

## CPU profiling

```
python3 -m cProfile -o docs/smithy/jobs/<slug>/reports/perf/profile.out <entry.py>
python3 -c "import pstats; pstats.Stats('...profile.out').sort_stats('cumulative').print_stats(15)"
```
Hot spots = top functions by cumulative and by tottime (report both views).

## Server endpoints

Latency via a low-concurrency load run (locust `-u 5`, or autocannon via npx
for plain HTTP) — hone measures speed, not capacity. Report p50 and p99.

## DB-heavy paths

`EXPLAIN ANALYZE` the queries the profile blames (read-only). N+1 detection:
log query counts per operation (SQLAlchemy `echo=True` to a file, or Django
`connection.queries` in a scratch harness).

## Rules

- Fixed inputs, documented in the brief — like-for-like comparisons only.
- Isolate: no autoreload servers or watchers running during measurement.
- Medians, never single runs; flag variance >10% between repeats.
