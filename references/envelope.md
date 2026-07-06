# Smithy Envelope — Inter-Agent Message Contract

Every smithy artifact that crosses an agent boundary (brief, report, verdict,
persona) OPENS with a machine-readable YAML envelope, then the human markdown
body. The envelope is how key information survives hops; the body is how
humans and reviewers read the detail.

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
  - docs/smithy/jobs/user-auth/reports/task-3-impl.md
key_facts:
  - "RangeError fires even when text is already short — only consistent reading of req 3"
concerns: []
next_action: "build review package for task-3"
---
```

## Fields

| Field | Required | Values / notes |
|---|---|---|
| `schema` | always | `1` — bump only on breaking format change |
| `kind` | always | `brief` \| `impl-report` \| `review-verdict` \| `rca` \| `test-report` \| `guild-verdict` \| `persona` |
| `job` | always | kebab-case slug (`-` for ad-hoc) |
| `unit` | always | `task-3`, `rca-1`, `wield`, `panel`, … |
| `agent` | reports | `forger` \| `jigsmith` \| `inspector` \| `inspector:<persona>` \| `annealer` \| `temperer` \| `controller` |
| `status` | reports/verdicts | the ledger vocabulary: `DONE DONE_WITH_CONCERNS NEEDS_CONTEXT BLOCKED APPROVED REJECTED PASS FAIL PARTIAL`; guild-verdict: `PRODUCTION_READY \| NOT_READY` |
| `confidence` | reports | 1–10; 9–10 only when verified by running/reading (creed §2) |
| `artifacts` | always | list of repo-relative paths this message produced/references |
| `key_facts` | always (may be `[]`) | facts a downstream agent MUST know — see below |
| `concerns` | always (may be `[]`) | unresolved worries, one line each |
| `next_action` | always | one line: what should happen next |

Lists are YAML block style (`- item`), strings quoted when they contain `:`.
Keep every list item to ONE line. No nested structures — flat by design so
`envelope.sh` can parse without a YAML library.

## key_facts — the loss-prevention channel

A key_fact is anything that changes what a downstream agent should do:
surprising constraints discovered mid-task, interpretation decisions taken,
environment quirks, "X looks wrong but is intentional because Y". If it lives
only in body prose, it dies at the next hop.

**Controller rule:** when writing the NEXT brief in a chain, copy forward
every unresolved `key_facts` and `concerns` item from the reports it consumed
into the new brief's envelope (drop only what was resolved, and say so in the
body). Agents MUST read the brief's envelope before the body.

## Tooling

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh get <file> <field>    # scalar
bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh list <file> <field>   # list items
bash ${CLAUDE_PLUGIN_ROOT}/scripts/envelope.sh validate <file>       # exit 0/1 + reasons
```

## Defensive rule

Missing or unparseable envelope in a report → treat as
`status: DONE_WITH_CONCERNS`, read the full body before proceeding, and tell
the agent's dispatcher to note the format violation. Never crash the pipeline
on a malformed envelope; never assume it means DONE.

## Compatibility

The envelope replaces the old "first body line MUST be `Status:`" contract as
the primary machine-read. Reports SHOULD still carry the `Status:` line as the
first body line after the envelope (defensive redundancy — costs one line).
