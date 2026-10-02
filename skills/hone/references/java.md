# Hone Playbook — Java / JVM

## Function benchmarks

- **JMH if the repo has it set up** (jmh plugin in the build file):
  `./gradlew jmh` / `mvn verify -Pjmh`, per the repo's setup. JMH handles
  warm-up and forking correctly — trust its output.
- **No JMH → do NOT hand-write `System.nanoTime()` loops** for small claims;
  the JIT breaks naive loops (it removes dead code, swaps code mid-loop).
  Measure at the operation level instead: a scratch `main` that runs the
  operation N times AFTER an explicit ≥10s warm-up loop, 3+ measured
  repeats, median — and label the numbers "operation-level, not JMH-grade"
  in the report.

## CPU / memory profiling

- Flight Recorder (ships with the JDK):
  `java -XX:StartFlightRecording=duration=60s,filename=<reports>/perf/hone.jfr -jar app.jar`
  then `jfr print --events jdk.ExecutionSample <file> | ...`, or list hot
  methods with `jfr view hot-methods <file>` (JDK 17+).
- Quick heap/GC picture: `jcmd <pid> GC.heap_info`, `jstat -gcutil <pid> 5s`.
- Where memory is allocated: `jfr view allocation-by-site <file>`.

## Server endpoints

Latency via autocannon at LOW concurrency (`-c 5`) — AFTER the ≥60s JIT
warm-up (see proof/java.md). Report p50 and p99, and say which warm-up you used.

## DB-heavy paths

`EXPLAIN ANALYZE` the queries the profile blames. Hibernate N+1 (one query
per row): turn on the repo's SQL logging (`spring.jpa.show-sql` or logger
config) in a scratch run and count queries per operation.

## Rules

- Same JVM flags for baseline and current runs — write them down.
- Medians of ≥3 measured repeats; flag >10% variance.
- Never compare a cold run with a warm one — that is the JIT, not your change.
