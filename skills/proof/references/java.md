# Proof Playbook — Java / JVM

## Load client (language-agnostic)

Default: `npx autocannon -c <conns> -d <secs> <url>`. Prefer `k6`/`wrk`/
JMeter/Gatling ONLY if already installed or already in the repo's tooling —
never install load tools into the user's project.

## Target under load — JVM warm-up is NOT optional

- Run the packaged artifact: `java -jar target/app.jar` (prod-ish flags from
  the repo's own docs/Dockerfile if present). Record heap flags used.
- **The JIT makes cold numbers meaningless.** The warm-up phase for a JVM
  target is longer: ≥60s of moderate load (not 10s) before any measured
  phase. Report warm-up separately and discard it.

## JVM-specific monitoring during runs

- `jcmd <pid> GC.heap_info` (or `jstat -gcutil <pid> 5s`) before / during-
  sustained / after-spike: report heap occupancy trend and GC pause behavior.
  Full-GC storms under sustained load = a finding even when p99 passes.
- Thread counts: `jcmd <pid> Thread.print | grep -c '^"'` at the same three
  points — unbounded thread-pool growth is a leak-class finding.
- If Flight Recorder is available: `jcmd <pid> JFR.start duration=60s
  filename=docs/smithy/jobs/<slug>/reports/perf/proof.jfr` during the
  sustained phase; attach the file path to the report.
- After the recovery run, heap and threads should return near baseline;
  a ratcheted floor = leak finding.

## Phases

Warm-up ≥60s (JIT) → ramp → sustained (agreed duration) → spike (2×, 15s) →
low-load recovery run.
