# Smithy Memory Protocol

Per-project memory lives in **`$SMITHY_MEM`** — a directory that may or may not
be inside the repo. Every path in every smithy skill is written relative to it.
Resolve it once per session, before anything else:

```bash
export SMITHY_MEM="$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh mem)"
```

**Never hardcode `docs/smithy`.** Plenty of projects clean, regenerate, or
gitignore `docs/`, which would silently destroy the ledger mid-job.

## Location

`paths.sh` resolves `$SMITHY_MEM` by the first rule that matches:

| # | Rule | Set by |
|---|---|---|
| 1 | `$SMITHY_MEM_DIR` env var | the user, per session |
| 2 | `<repo>/.smithy-path` — one-line pointer file | `init-memory.sh --at <dir> --pointer` |
| 3 | `$SMITHY_HOME/projects.tsv` registry (outside the repo) | `init-memory.sh --external`, `paths.sh set-mem` |
| 4 | `<repo>/docs/smithy/` when it already exists | legacy projects — keeps working untouched |
| 5 | global `memory.location`: `repo` \| `external` | `/smithy:calibrate` |

`$SMITHY_HOME` = `$SMITHY_HOME` env → `$XDG_CONFIG_HOME/smithy` → `~/.smithy`.

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh --dump` shows the resolved dir and
which rule produced it. Rules 1–4 are pure bash so the PreToolUse guard hook can
resolve paths without an interpreter spawn.

### Bootstrapping a project

Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh` (idempotent).

**If it exits 3, the location is undecided and the script refuses to guess.**
ASK THE USER, then re-run with their answer:

| Choice | Flag | When it's right |
|---|---|---|
| in the repo | `--in-repo` | memory is reviewable/committable with the code |
| outside the repo | `--external` | the repo cleans/regenerates/gitignores `docs/` |
| a specific dir | `--at <dir>` | a shared drive, a sibling notes repo, a monorepo corner |

Add `--pointer` to also drop `<repo>/.smithy-path` so a fresh clone on another
machine finds the same dir (the registry is per-machine). Add
`--global-default repo|external` to stop being asked in future projects.

Then re-export `$SMITHY_MEM` — it changed.

## File map

```
$SMITHY_MEM/
├── STATE.md          # THE index. Hard cap 40 lines. Overwritten, never appended.
├── config.json       # this project's config overrides (sparse; /calibrate writes it)
├── ledger.md         # append-only event log — write ONLY via scripts/ledger.sh
├── decisions.md      # append-only decision log, ≤3 lines per entry
├── DESIGN.md         # design source of truth, when /smithy:pattern has run
├── personas/         # test personas, when /smithy:commission has run
└── jobs/<slug>/      # one dir per work item, slug = kebab-case feature name
    ├── spec.md              # assay output
    ├── plan.md              # blueprint output
    ├── briefs/task-N.md     # per-task forger briefs
    ├── reports/             # forge-report.md (per-task files are transient scratch,
    │                        #   consolidated + deleted at forge exit), rca-*.md,
    │                        #   test-*.md, temper-summary.md, guild-verdict.md/json
    └── handoff.md           # handover output (overwritten each handoff)
```

Guard tokens (`.git-grant`, `.push-once`, `.destructive-once`) also live here and
are gitignored when memory is in-repo.

## Config layers

Three layers merge per key, lowest precedence first:

| Layer | File | Scope |
|---|---|---|
| defaults | `${CLAUDE_PLUGIN_ROOT}/defaults/config.json` | ships with the plugin; never edit per project |
| global | `$SMITHY_HOME/config.json` | **every project** on this machine |
| project | `$SMITHY_MEM/config.json` | this project only |

Read any key with its provenance:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get    implementation.tdd
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh source implementation.tdd   # -> defaults|global|project
bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh --dump                     # routing table + layers
```

`/smithy:calibrate` is the only sanctioned writer of the global and project
layers. Both stay SPARSE — they hold only what differs from the layer below.

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

Artifact paths in the ledger are relative to `$SMITHY_MEM`, so a relocated
memory dir does not invalidate history.

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
| calibrate | all three config layers | global and/or project config.json, ledger |
| smithy (orchestrator) | all of the above | STATE.md at every phase boundary, ledger gate lines |

## Leanness rules

- STATE.md ≤ 40 lines. Ledger entries are single lines. decisions.md entries ≤ 3 lines.
- Mandatory writes only at: skill start, unit completion, phase boundary. Never mid-task.
- Memory files hold **paths to artifacts, never artifact contents**.

## Recovery rule

Conversation memory does not survive compaction or session death.
**Trust STATE.md, the ledger, and `git log` over your own recollection.**
On resume: re-export `$SMITHY_MEM` → read STATE.md → confirm with
`ledger.sh tail` → cross-check `git log --oneline <base>..HEAD` → resume at the
first unit that has no `DONE`/`APPROVED` ledger line. Units marked complete are
never re-dispatched.
