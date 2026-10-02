---
name: proof
description: "Stress / load test a running service against limits the user sets (never invented), on a local or user-approved target only. Works inside a job or on its own. Triggers: 'proof', 'stress test', 'load test'."
---

# Proof — Stress Test

Proofing a blade means loading it on purpose until you see where it bends.
Here: push a running service through four load phases and compare what you
measure with limits the user chose.

```
warm-up (low, 10s) ─▶ ramp (step up to target) ─▶ sustained (target, agreed time) ─▶ spike (2×, 15s) ─▶ recovery (low)
      discard              record each step            the main verdict              where it breaks     back to normal?
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh proof auto` — read its summary.
   Called by temper: `start.sh proof <temper's slug>` so both log to the same job.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`.

## Needs

All three are part of the job itself. Missing one → **stop** and say
exactly what is missing and how to give it.

| Needs | If it exists | If it is missing |
|---|---|---|
| A runnable service | run command + URL: the LATEST line starting `run:` in `<memory>/decisions.md` (`run: <start command> \| url: <url>`) | ask the user once, then append that `run:` line to decisions.md. No service at all → proof does not apply; suggest `/smithy:hone` for speed work |
| A safe target | a LOCAL target, or a host the user approved in writing THIS session | stop. Never load-test production or any host the user has not named this session |
| Limits (thresholds) from the user | the user's numbers | offer this default and get an explicit yes: p99 < 500ms, 0 errors (5xx), 50 concurrent connections for 60s. The user may change any number. **Never invent a limit** |

## Steps

1. **Pick the tools** (`${CLAUDE_PLUGIN_ROOT}/references/stacks.md` tool matrix) — the load
   client does not care what language the service is in: default
   `npx autocannon` for any HTTP target; locust for Python; k6 / wrk / hey /
   vegeta only if already installed. The stack playbook
   (`${CLAUDE_PLUGIN_ROOT}/skills/proof/references/ts.md`, `python.md`, `go.md`, `java.md`,
   `rust.md`) sets how to build and run the target (release builds, JVM
   warm-up) and what to watch while it runs (pprof, jcmd/JFR, memory, open files).
   → verify: load tool, playbook path and the service's run + readiness commands are named.

2. **Write the brief** `jobs/<slug>/briefs/proof.md` (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
   §3): the run command and readiness check; endpoints; exact tool commands
   for the four phases plus recovery (picture above; the playbook may set a
   longer warm-up, e.g. JVM); the limits table; report path
   `jobs/<slug>/reports/test-stress.md`.
   `## Persona`: `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/sre.md` (test lens: how it
   fails, what to watch).
   → verify: the brief has every phase command and every agreed limit.

3. **Dispatch** one `temperer` (role `testing`; `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`
   §1–2: banner + paths + "Job <slug>, proof"). It copies tool output word
   for word per phase — every number in the report must appear in tool output.
   → verify: the report exists; read its status with `envelope.sh get <report> status`.

4. **Read the report** — a table: each limit PASS/FAIL with the measured
   value. Plus the **saturation point** (where the latency or error curve
   bent) and the **first failure mode** (what broke first: latency, errors,
   memory, threads, open files?).
   → verify: every agreed limit has a measured value and a verdict.

5. **Log** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append proof <slug> suite <PASS|FAIL|PARTIAL> jobs/<slug>/reports/test-stress.md`.
   → verify: `ledger.sh tail 1` shows the line.

## Done when

- [ ] the target is local or user-approved this session (say which)
- [ ] every limit came from the user (quote the yes)
- [ ] every agreed limit has a measured value and a PASS/FAIL
- [ ] FAIL → the report names the first failure mode, with evidence
- [ ] every number in the report appears in tool output
- [ ] ledger line written under `proof`

## Output

`jobs/<slug>/briefs/proof.md` · `jobs/<slug>/reports/test-stress.md`.

`Next: /smithy:hone — measure speed of the hot paths` · or, on FAIL: `Next: /smithy:anneal — find why it breaks under load`.

## Red flags

| Thought | Reality |
|---|---|
| "500ms is a normal limit, I'll use it" | Only with the user's yes. Never invent a limit. |
| "Staging is basically local" | Only hosts the user named this session. |
| "A debug build is fine for a quick look" | Numbers from debug or race builds are invalid. |
