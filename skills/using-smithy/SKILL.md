---
name: using-smithy
description: "Skill router: which smithy skill to use when, what each one needs to run, the priority rules, and the thoughts that mean STOP. A short digest is injected each session; invoke this for the full router."
---

# Using Smithy

Smithy is a full dev pipeline made of skills. This file is the router: it
says WHEN to use which skill, what each skill needs, and which excuses lead
to skipping them.

```
idea ──▶ assay ──▶ blueprint ──▶ forge / jig ──▶ inspect · guild ──▶ temper ──▶ ship
        (spec)     (plan)        (build)         (review)            (test)
   small known change ──▶ strike          failure ──▶ anneal (find the cause first)
```

<CRITICAL>
If a smithy skill fits the task — even maybe — invoke it BEFORE you answer,
ask questions, or explore the code. The skill does those steps for you, with
its safeguards. Doing them by hand first wastes work and skips the checks.
If the skill turns out not to fit, say so and step out — but check first.
</CRITICAL>

## Which skill — trigger → skill (plain alias in brackets)

Every skill also has a plain alias slash command: `/smithy:plan` runs
`smithy:blueprint`, and so on.

| The user wants / the situation is | Skill (alias) |
|---|---|
| Build a feature end to end, "take this from idea to tested code" | `/smithy:smithy` (`pipeline`) |
| Understand the ask, explore before building, "write a spec" | `/smithy:assay` (`research`) |
| Break the work into a plan and tasks | `/smithy:blueprint` (`plan`) |
| Build the plan — one review at the end | `/smithy:forge` (`implement`) |
| Test-first / "TDD this" / a bug fix with a repro — one clean commit per task | `/smithy:jig` (`tdd`) |
| "Review this change / diff / branch" | `/smithy:inspect` (`code-review`) |
| "Is this ready to ship?" / review from many viewpoints | `/smithy:guild` (`review-panel`) |
| "Who uses this system?" / define test personas | `/smithy:commission` (`personas`) |
| "Create a design" / a design system (before UI work) | `/smithy:pattern` (`design`) |
| "Review / improve the design", "polish the UI" | `/smithy:burnish` (`design-review`) |
| A small KNOWN change, a quick fix, fixes from a review or QA | `/smithy:strike` (`fix`) |
| A bug or failure whose cause is unknown, "why is this broken" | `/smithy:anneal` (`debug`) |
| "Test everything" after building | `/smithy:temper` (`test`) |
| Unit tests only | `/smithy:ring-test` (`unit-test`) |
| "Does it actually work?" — QA as a user | `/smithy:wield` (`qa`) |
| "Will it survive load?" | `/smithy:proof` (`stress-test`) |
| "Why is it slow?" / benchmark | `/smithy:hone` (`perf-test`) |
| End of session, "summarize for next time" | `/smithy:handover` (`handoff`) |
| Change models, effort, TDD settings, gates, memory location | `/smithy:calibrate` (`config`) |

## What each skill needs to run

Every skill works on its own. A missing upstream file (spec, plan, brief)
never stops a skill: it falls back — asks a few questions, writes a small
version, confirms it with the user — and keeps going. Only things that are
truly part of the job can stop a skill, and then it says exactly what is
missing.

| Skill | Must have | Uses if present (else falls back) |
|---|---|---|
| smithy, assay, strike | the user's request | STATE.md, past specs, memory lookups |
| blueprint | the user's request | `spec.md` — else asks a few questions first |
| forge, jig | the user's request | `plan.md` + briefs — else writes one brief and confirms it |
| inspect, guild | a diff to review (a base: `--base <ref>`) | the plan as the brief — else a short brief from the user's words |
| wield | a runnable app | project personas, the spec |
| proof | a running LOCAL service + the user's thresholds (never invented) | the spec |
| burnish | a running LOCAL UI + Playwright | `DESIGN.md` |
| hone | something to measure | an earlier baseline |
| ring-test | code to test | the stack playbook |
| temper | code (each suite has its own needs) | the plan, earlier reports |
| anneal | a failure and a way to reproduce it | earlier reports, the ledger |
| calibrate, handover, commission, pattern | nothing else | STATE.md, the ledger |

## Priority rules

1. **Process before code — sized to the work.**
   - A **feature** ("build X", new behavior) enters at `assay` (or the
     `smithy` pipeline), never straight at forge — even when it looks fully
     specified. Assay on a clear request is cheap; a wrong guess in forge
     is not.
   - A **small known change** (a rename, a config tweak, a listed fix-up,
     findings from a review or QA) goes to `strike`. It needs no spec or plan.
   - A **failure whose cause is unknown** goes to `anneal` (rule 2).
   Unsure which? Ask the user, with a recommendation.
2. **Find the cause before the fix.** An unexpected failure goes to `anneal`
   before any fix is tried — including failures inside forge or temper.
3. **The ledger beats memory.** Every skill starts with `${CLAUDE_PLUGIN_ROOT}/scripts/start.sh`,
   which reads STATE.md and the ledger. Trust that and `git log` over what
   you remember about the project.
4. **One writer per file.** The ledger only through `ledger.sh`; config only
   through `calibrate`; STATE.md per `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`.
5. **The user's instructions win.** If the user says to skip a phase or a
   gate, do it — say once which safeguard is skipped, then do not nag.
6. **Git is guarded by a hook.** A hook blocks push, history rewrites and
   commits that were not approved. A block is the system working — report
   it, never work around it (creed §6).
7. **Lookup tools are helpers** (creed §10). Memory, code-graph and docs
   tools the user has installed may be used freely when they only READ —
   by skills and by agents. A tool that sends, creates, updates or deletes
   anything needs the user's yes first (a hook asks automatically). No tool
   is ever required: without one, use Read / Grep / Glob / Bash and say so
   in one line. Budget per run: 1 search, 1 timeline, 3 records. A lookup is
   a lead to check, not a fact.
8. **Two harnesses, one set of rules.** Under Codex CLI (AGENTS.md entry)
   read `${CLAUDE_PLUGIN_ROOT}/references/harness.md` first: dispatch becomes `spawn_agent` /
   `wait_agent` / `close_agent`, models are the GPT family (sol / terra /
   luna, plus older gpt-* ids), and NO hooks run there — so creed §6 is the
   only guard, and you apply routing by hand.

## Red flags — these thoughts mean STOP

| Thought | Reality |
|---|---|
| "The feature is clear, I can skip assay" | Clear-looking requests hide guesses. Assay turns them into questions. |
| "It's a one-line fix for a bug I don't understand" | A fix without a cause brings the bug back next week. Anneal first. (A KNOWN small change is strike.) |
| "I remember where the pipeline was" | Memory dies at compaction. STATE.md and the ledger survive. Read them. |
| "I'll paste the report into the prompt, it's short" | Pasted text stays in context for the whole session. Hand over paths. |
| "The tests will obviously pass, mark it done" | Evidence before claims. Run them; cite the output. |
| "The upstream skill hasn't run, so I can't start" | Every skill has a fallback. Use it; ask, or recommend one option and say why. |
| "I'll skip the gate, the user would approve" | Gates exist because "would approve" has been wrong before. Ask. |

## On its own or in the pipeline

Every phase skill works on its own (see the table above) and in the
`smithy` pipeline. Run on its own, a skill still writes memory (ledger
lines, reports), which is what makes resuming and trend tracking work.
Skills are cheap to enter and safe to leave: when in doubt, enter the skill.
