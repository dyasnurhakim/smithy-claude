# Hone Playbook — Java / JVM

## Micro/function benchmarks

- **JMH if the repo has it configured** (jmh plugin in the build file):
  `./gradlew jmh` / `mvn verify -Pjmh` per the repo's setup. JMH handles
  warm-up/forking correctly — trust its output format.
- **No JMH → do NOT hand-roll `System.nanoTime()` loops** for micro-claims;
  the JIT invalidates naive loops (dead-code elimination, OSR). Instead
  measure at operation level: a scratch `main` that runs the operation N
  times AFTER an explicit ≥10s warm-up loop, 3+ measured repeats, median —
  and label the numbers "operation-level, not JMH-grade" in the report.

## CPU / memory profiling

- Flight Recorder (ships with the JDK):
  `java -XX:StartFlightRecording=duration=60s,filename=<reports>/perf/hone.jfr -jar app.jar`
  then `jfr print --events jdk.ExecutionSample <file> | ...` or summarize hot
  methods with `jfr view hot-methods <file>` (JDK 17+).
- Quick heap/GC picture: `jcmd <pid> GC.heap_info`, `jstat -gcutil <pid> 5s`.
- Allocation hot spots: `jfr view allocation-by-site <file>`.

## Server endpoints

Latency via autocannon at LOW concurrency (`-c 5`) — AFTER the ≥60s JIT
warm-up (see proof/java.md). Report p50 and p99, and state the warm-up used.

## DB-heavy paths

`EXPLAIN ANALYZE` the queries the profile blames. Hibernate N+1 detection:
enable the repo's SQL logging (`spring.jpa.show-sql` or logger config) in a
scratch run and count queries per operation.

## Rules

- Same JVM flags between baseline and current runs — record them.
- Medians of ≥3 measured repeats; flag >10% variance.
- Never compare a cold run to a warm one — that's the JIT, not your change.
