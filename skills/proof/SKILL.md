---
name: proof
description: Stress/load-test a running service — concurrency, sustained load, spike behavior — against user-set thresholds. Use when asked to "proof", "stress test", "load test", "will it hold up under load", or as part of /smithy:temper when a service exists.
---

# Proof — Stress Test

(Proofing a blade = deliberate overload to find where it breaks.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append temper <slug> proof STARTED -`

## Preconditions — all three, or stop

1. **A runnable service.** Run command + target URL from spec.md/STATE.md, or
   ask. No service → tell the user proof doesn't apply; suggest `/smithy:hone`
   for non-service performance work.
2. **A safe target.** LOCAL or explicitly user-approved environments only.
   Never load-test a production URL or any host the user hasn't named in
   writing this session.
3. **Thresholds from the user.** Never invent SLOs. Offer this default and
   get explicit confirmation: p99 < 500ms, 0 errors (5xx), at 50 concurrent
   connections for 60s. The user may change any number.

## Process

1. **Detect tooling** (stacks.md matrix): the load client is language-
   agnostic — default `npx autocannon` for any HTTP target; locust for
   Python; k6/wrk/hey/vegeta only if already installed. The per-stack
   playbook (`references/{ts,python,go,java,rust}.md`) sets the build/run
   discipline (release builds, JVM warm-up) and the runtime monitoring hooks
   (pprof, jcmd/JFR, RSS/fd tracking).

2. **Write the test brief** (`briefs/proof.md`): tool + exact invocations for
   four phases — warm-up (low load, 10s), ramp (step to target), sustained
   (target load, the agreed duration), spike (2× target, 15s) — endpoints,
   thresholds table, report path `reports/test-stress.md`. Include the run
   command for the service and the readiness check.

3. **Dispatch `smithy:temperer`** (routing role `testing`). The temperer captures
   tool output verbatim per phase — every number in the report must appear in
   tool output.

4. **Read the report.** Verdict table: each threshold PASS/FAIL with measured
   value. Plus: saturation point (where latency/error curves bent) and first
   failure mode (what degraded first: latency, errors, memory?).

5. **Log:** `ledger.sh append temper <slug> proof <PASS|FAIL|PARTIAL> reports/test-stress.md`

## Exit criteria

Every agreed threshold has a measured verdict. FAIL → the report names the
first failure mode with evidence.

Handoff: "FAIL → `/smithy:anneal` with `reports/test-stress.md`. Next: `/smithy:hone`."
