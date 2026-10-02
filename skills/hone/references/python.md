# Hone Playbook — Python

## Function benchmarks

- pytest-benchmark if present: `uv run pytest --benchmark-only`.
- Otherwise `timeit` in a scratch script: ≥3 repeats
  (`timeit.repeat(..., repeat=3)`); report the MEDIAN of the repeats.

## CPU profiling

```
python3 -m cProfile -o $SMITHY_MEM/jobs/<slug>/reports/perf/profile.out <entry.py>
python3 -c "import pstats; pstats.Stats('...profile.out').sort_stats('cumulative').print_stats(15)"
```
Hot spots = top functions by cumulative time and by tottime (report both views).

## Server endpoints

Latency via a low-concurrency load run (locust `-u 5`, or autocannon via npx
for plain HTTP) — hone measures speed, not capacity. Report p50 and p99.

## DB-heavy paths

`EXPLAIN ANALYZE` the queries the profile blames (read-only). N+1 (one
query per row): log query counts per operation (SQLAlchemy `echo=True` to a
file, or Django `connection.queries` in a scratch harness).

## Rules

- Fixed inputs, written in the brief — compare like with like only.
- Keep it quiet: no autoreload servers or watchers running while you measure.
- Medians, never single runs; flag >10% variance between repeats.
