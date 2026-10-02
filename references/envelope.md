# Smithy Envelope — the header on every message between agents

Every smithy file that passes from one agent to another (brief, report,
verdict, persona) OPENS with a small YAML header: the **envelope**. Scripts
read the envelope; people and reviewers read the markdown body below it.
The envelope is how key facts survive each hand-off.

```
┌─ ---smithy ──────────────┐
│ kind, job, unit, status  │  ← scripts read this (envelope.sh)
│ key_facts, concerns      │  ← what the next agent MUST know
├─ --- ────────────────────┤
│ Status: DONE             │  ← first body line
│ # the human report …     │  ← people read this
└──────────────────────────┘
```

## Format

The envelope is the FIRST thing in the file — line 1 is the opening marker:

```
---smithy
schema: 1
kind: impl-report
job: user-auth
unit: task-3
agent: jigsmith
status: DONE
confidence: 9
artifacts:
  - jobs/user-auth/reports/task-3-impl.md
key_facts:
  - "RangeError fires even when text is already short — only consistent reading of req 3"
concerns: []
next_action: "final review of the job"
---
```

## Fields

| Field | Required | Values / notes |
|---|---|---|
| `schema` | always | `1` — change only when the format breaks old readers |
| `kind` | always | `brief` \| `impl-report` \| `review-verdict` \| `rca` \| `test-report` \| `guild-verdict` \| `forge-report` \| `persona` |
| `job` | always | the kebab-case job slug (`-` when there is no job) |
| `unit` | always | `task-3`, `rca-1`, `wield`, `panel`, `audit`, … |
| `agent` | reports | `forger` \| `jigsmith` \| `inspector` \| `inspector:<persona>` \| `annealer` \| `temperer` \| `controller` |
| `status` | reports, verdicts | the ledger words: `DONE DONE_WITH_CONCERNS NEEDS_CONTEXT BLOCKED APPROVED REJECTED PASS FAIL PARTIAL`; rca (annealer reports): `ROOT_CAUSE_FOUND \| INCONCLUSIVE \| CANNOT_REPRODUCE`; guild-verdict: `PRODUCTION_READY \| NOT_READY` |
| `confidence` | reports | 1–10; 9–10 only when checked by running or reading (creed §2) |
| `artifacts` | reports, verdicts (optional in a brief) | paths this message made or points to (relative to the repo or the memory folder) |
| `key_facts` | always (may be `[]`) | facts the next agent MUST know — see below |
| `concerns` | always (may be `[]`) | open worries, one line each |
| `next_action` | reports, verdicts (optional in a brief) | one line: what should happen next |

Lists use YAML block style (`- item`). Quote a string when it has a `:`.
Every list item is ONE line. Nothing nested — kept flat on purpose so
`envelope.sh` can read it without a YAML library.

## key_facts — so nothing gets lost between agents

A key fact is anything that changes what the next agent should do: a
surprising limit found mid-task, a choice made about how to read a
requirement, an odd thing about the environment, "X looks wrong but is
on purpose because Y". If it lives only in the body text, it is lost at the
next hand-off.

**Controller rule:** when you write the NEXT brief in a chain, copy every
open `key_facts` and `concerns` item from the reports you used into the new
brief's envelope. Drop only what was resolved, and say so in the body.
Agents read the brief's envelope before its body.

## Tooling

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh get <file> <field>    # one value
bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh list <file> <field>   # list items
bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh validate <file>       # exit 0/1 + reasons
```

## Finding fingerprint (one definition for every skill)

Skills that track findings across runs (wield, guild, burnish, hone) give
each finding the same id, so "is this the same problem as last time?" has
one answer:

```
fingerprint = first 12 hex chars of sha256( category + file + normalized title )
normalized title = lower case, spaces collapsed to one, trimmed
file = repo-relative path, or the route/screen name for UI findings
```

Plain concatenation, no separators. Same formula wield used before 0.14,
so old trend files still match.

Same fingerprint in two reports = the same finding (merge it; keep the
higher severity). Across runs: Resolved / Persistent / New.

## Defensive rule

A report with a missing or unreadable envelope → treat it as
`status: DONE_WITH_CONCERNS`, read the whole body before going on, and tell
whoever dispatched that agent to mention the format problem next time.
Never crash the pipeline on a broken envelope. Never assume it means DONE.

## The `Status:` line

The envelope is what scripts read first. Reports still put a `Status:` line
as the first body line after the envelope — a backup that costs one line.
