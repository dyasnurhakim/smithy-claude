# Proof Playbook — Java / JVM

## Load client (any language)

Default: `npx autocannon -c <conns> -d <secs> <url>`. Use `k6` / `wrk` /
JMeter / Gatling ONLY if already installed or already in the repo's tooling —
never install load tools into the user's project.

## The target under load — JVM warm-up is NOT optional

- Run the packaged artifact: `java -jar target/app.jar` (with prod-like
  flags from the repo's own docs/Dockerfile if present). Write down the heap
  flags used.
- **The JIT (the JVM's run-time compiler) makes cold numbers meaningless.**
  Warm-up for a JVM target is longer: ≥60s of moderate load (not 10s)
  before any measured phase. Report warm-up separately and throw it away.

## What to watch during runs (JVM)

- `jcmd <pid> GC.heap_info` (or `jstat -gcutil <pid> 5s`) before / during
  sustained load / after the spike: report how heap use and GC pauses
  change. Full-GC storms under sustained load = a finding, even when p99 passes.
- Thread counts: `jcmd <pid> Thread.print | grep -c '^"'` at the same three
  points — a thread pool that keeps growing is a leak-type finding.
- If Flight Recorder is available: `jcmd <pid> JFR.start duration=60s
  filename=$SMITHY_MEM/jobs/<slug>/reports/perf/proof.jfr` during the
  sustained phase; add the file path to the report.
- After the recovery run, heap and threads should come back near baseline;
  a floor that keeps rising = a leak finding.

## Phases

Warm-up ≥60s (JIT) → ramp → sustained (agreed duration) → spike (2×, 15s) →
low-load recovery run.
