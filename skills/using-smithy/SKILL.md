---
name: using-smithy
description: Use when starting any conversation in a project where smithy is installed — establishes when to use which smithy skill, the priority rules between them, and the rationalizations that lead to skipping them. Injected automatically by the SessionStart hook.
---

# Using Smithy

Smithy is a full dev pipeline. This skill is the router: it tells you WHEN to
reach for which smithy skill, and it names the rationalizations that lead to
skipping them.

<CRITICAL>
If a smithy skill applies to the task at hand — even plausibly — invoke it
BEFORE responding, before clarifying questions, before exploring the code.
The skills front-load exactly those steps; doing them ad-hoc first duplicates
work and skips their safeguards. If the skill turns out not to fit, you can
say so and step out — but the check comes first.
</CRITICAL>

## Routing table — trigger → skill

| The user wants / the situation is | Skill |
|---|---|
| Build a feature end-to-end, "take this from idea to tested code" | `/smithy:smithy` (orchestrator) |
| Understand requirements, explore before building, "write a spec" | `/smithy:assay` |
| A spec exists; break work into tasks/plan | `/smithy:blueprint` |
| An approved plan exists; implement it | `/smithy:forge` |
| Implement test-first / "TDD this" / fixing a bug with a repro | `/smithy:jig` |
| "Review this change/task/diff" | `/smithy:inspect` |
| A bug, unexpected failure, "why is this broken" | `/smithy:anneal` |
| "Test everything" after implementation | `/smithy:temper` |
| Unit tests only | `/smithy:ring-test` |
| "Does it actually work?" — functional QA | `/smithy:wield` |
| "Will it survive load?" | `/smithy:proof` |
| "Why is it slow?" / benchmark | `/smithy:hone` |
| Ending a session, "summarize for next time" | `/smithy:handover` |
| Change which model/effort a role uses, TDD default, gates | `/smithy:calibrate` |

## Priority rules

1. **Process before implementation.** A request to "build X" enters at
   `assay` (or the orchestrator), never directly at `forge` — even when the
   request seems fully specified. Assay on a clear request is cheap; a wrong
   assumption in forge is not.
2. **RCA before fix.** Any unexpected failure routes to `anneal` before any
   fix is attempted — including failures inside forge/temper.
3. **The ledger outranks memory.** If `docs/smithy/STATE.md` exists, read it
   and `ledger.sh tail` before acting on any recollection of project state.
4. **One writer per file.** Ledger via `ledger.sh` only; config via
   `calibrate` only; STATE.md per the memory protocol.
5. **User instructions outrank smithy.** If the user explicitly says to skip
   a phase or gate, follow them — state what safeguard is being skipped, once,
   without nagging.

## Red flags — these thoughts mean STOP

| Thought | Reality |
|---|---|
| "The request is clear, I can skip assay" | Silent assumptions are exactly how clear-seeming requests go wrong. Assay converts them to questions — that's the point. |
| "It's a one-line fix, no need for anneal" | One-line fixes without RCA are how the same bug returns next week. |
| "I remember where the pipeline was" | Recollection dies at compaction. STATE.md + ledger survive. Read them. |
| "I'll paste the report into my prompt, it's short" | Everything pasted stays resident in context forever. Hand over paths. |
| "The tests will obviously pass, mark it done" | Evidence before assertion. Run them; paste the output in the report. |
| "This project doesn't need memory files" | The first resumed session disagrees. `init-memory.sh` is idempotent and cheap. |
| "I'll skip the gate, the user probably approves" | Gates exist because "probably" has been wrong before. Ask. |

## Standalone vs pipeline

Every phase skill works standalone (each documents its standalone mode).
Standalone use still writes memory (ledger lines, reports) — that's what
makes later resumption and trend tracking possible. Skills are cheap to
enter and safe to exit; when in doubt, enter the skill.
