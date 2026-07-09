# Smithy Memory Protocol

Per-project memory lives in the target project at `docs/smithy/`. Scaffold it
with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh` (idempotent).

## File map

```
docs/smithy/
├── STATE.md          # THE index. Hard cap 40 lines. Overwritten, never appended.
├── config.json       # routing overrides (sparse — only changed keys; /calibrate writes it)
├── ledger.md         # append-only event log — write ONLY via scripts/ledger.sh
├── decisions.md      # append-only decision log, ≤3 lines per entry
└── jobs/<slug>/      # one dir per work item, slug = kebab-case feature name
    ├── spec.md              # assay output
    ├── plan.md              # blueprint output
    ├── briefs/task-N.md     # per-task forger briefs
    ├── reports/             # forge-report.md (per-task files are transient scratch,
    │                        #   consolidated + deleted at forge exit), rca-*.md,
    │                        #   test-*.md, temper-summary.md, guild-verdict.md/json
    └── handoff.md           # handover output (overwritten each handoff)
```

## STATE.md format (exact — keep all six lines, ≤40 lines total)

```markdown
# Smithy State
- Active job: jobs/<slug>/
- Phase: ASSAY|BLUEPRINT|FORGE|TEMPER|IDLE (task N of M)
- Base sha: <sha|none>
- Last event: <ISO-ts> <phase> <unit> <STATUS>
- Blockers: <text|none>
- Next step: <one concrete action with its artifact path>
```

## Ledger

One line per event, written only via `ledger.sh append <phase> <job> <unit> <status> <artifact>`:

```
2026-07-06T10:22Z | forge | user-auth | task-2 | DONE | jobs/user-auth/reports/task-2-impl.md
```

Statuses: `STARTED DONE DONE_WITH_CONCERNS NEEDS_CONTEXT BLOCKED APPROVED REJECTED PASS FAIL PARTIAL`

## Who writes what

| Skill | Reads | Writes |
|---|---|---|
| every skill, step 1 | STATE.md, `ledger.sh tail` | one `STARTED` ledger line |
| assay | — | `jobs/<slug>/spec.md`, decisions.md (resolved ambiguities), STATE.md |
| blueprint | spec.md | plan.md, briefs/task-*.md, decisions.md, STATE.md |
| forge / jig | plan.md, briefs, config `implementation.tdd` | ledger per task, STATE.md, decisions.md (TDD choice) (agent writes reports/) |
| inspect | brief + review package | ledger verdict, controller notes appended to review report (agent writes reports/) |
| anneal | failing report/context | decisions.md (fix decision), ledger (agent writes rca) |
| test skills + temper | plan.md, stack-detect output | reports/test-*.md, temper-summary.md, ledger |
| handover | STATE.md, ledger, reports | handoff.md, STATE.md |
| calibrate | config.json | config.json, ledger |
| smithy (orchestrator) | all of the above | STATE.md at every phase boundary, ledger gate lines |

## Leanness rules

- STATE.md ≤ 40 lines. Ledger entries are single lines. decisions.md entries ≤ 3 lines.
- Mandatory writes only at: skill start, unit completion, phase boundary. Never mid-task.
- Memory files hold **paths to artifacts, never artifact contents**.

## Recovery rule

Conversation memory does not survive compaction or session death.
**Trust STATE.md, the ledger, and `git log` over your own recollection.**
On resume: read STATE.md → confirm with `ledger.sh tail` → cross-check
`git log --oneline <base>..HEAD` → resume at the first unit that has no
`DONE`/`APPROVED` ledger line. Units marked complete are never re-dispatched.
