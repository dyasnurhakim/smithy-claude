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
├── lanes/<name>/     # per-lane STATE.md + ledger.md + decisions.md (see § Lanes)
│   └── .merged/      # lanes already folded back in, kept for audit
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

## Lanes — parallel work without a shared-state collision

`$SMITHY_MEM` is one directory per PROJECT, anchored on the MAIN worktree. That
is deliberate — a ledger that silently splits per worktree is worse than one
that is shared — but it means two concurrent units of work would append to the
same `ledger.md` and overwrite the same single-`Active job` `STATE.md`.

A **lane** namespaces exactly the mutable files:

| Lane-scoped (per unit) | Project-wide (never lane-scoped) |
|---|---|
| `STATE.md`, `ledger.md`, `decisions.md` | `config.json`, `jobs/`, `personas/`, `DESIGN.md`, guard tokens |

Config is not lane-scoped because a lane is a unit of work, not a different set
of preferences. Guard tokens are not, because authorization belongs to the user
and the project — a lane must never be able to mint itself a commit grant.

Resolution, first match wins (pure bash, so the guard hook stays fast):

| # | Rule | Set by |
|---|---|---|
| 1 | `$SMITHY_LANE` env var | a dispatcher pinning one agent to one lane |
| 2 | `<this worktree>/.smithy-lane` marker | `worktree.sh create`, automatically |
| 3 | none → state dir is `$SMITHY_MEM` | ordinary serial work |

Lane names are `[A-Za-z0-9._-]`, no leading dot, no `..` — the name becomes a
path segment. An invalid one is IGNORED (falls back to the shared dir), never
sanitised into a different lane.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh start <name> [--worktree <path>] [--job <slug>]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh list | current | status
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh merge <name>      # fold into the project state
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh merge-all         # after a whole batch lands
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh abandon <name>    # rolled-back work
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh where           # which file am I appending to?
```

**Reads are always merged, writes never are.** Inside a lane, `ledger.sh tail`
returns the lane's events merged over the project's in timestamp order — so a
controller resuming after compaction sees the whole history, not just its own
slice, and reaches the same resume decision it would have reached serially.
Appends still go only to the lane.

**Merging** is a timestamp-stable union: the ledger is append-only with a
leading ISO timestamp, so combining lanes is a sort, not a three-way merge —
no conflicts, no lost events, and each lane's internal order is preserved
within a tied minute. `merge` also appends the lane's `decisions.md`, refreshes
the project `STATE.md`'s `Last event` line, and archives the lane under
`lanes/.merged/`. It deliberately does NOT rewrite `Phase` or `Next step` —
those are semantic and belong to the controller.

**Merge, or abandon, before the job ends.** An unmerged lane is work the next
session cannot see, and the recovery rule below tells it to trust the ledger
over recollection. `worktree.sh remove` reports unmerged lanes rather than
merging them, because a removed checkout is disposable and an event log is not.

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

Keys the pipeline reads most often:

| Key | Values | Read by |
|---|---|---|
| `implementation.tdd` | ask \| always \| never | forge step 0 |
| `implementation.tdd_level` | minimal \| balanced \| max | forge, jig → the brief |
| `implementation.tdd_commits` | git \| local | forge (grant precondition), jig (evidence check) |
| `implementation.max_fix_cycles` | int (default 2) | forge step 6, dispatch.md §6 |
| `gates.*`, `testing.skip`, `review_panel` | see `/smithy:calibrate` | smithy, temper, guild |

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
| forge / jig | plan.md, briefs, config `implementation.*` | ledger per task, STATE.md, decisions.md (TDD choice), lane merges after a parallel batch (agent writes reports/) |
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
`ledger.sh tail` → **check `lane.sh list` for unmerged lanes** → cross-check
`git log --oneline <base>..HEAD` → resume at the first unit that has no
`DONE`/`APPROVED` ledger line. Units marked complete are never re-dispatched.

An unmerged lane means a previous session died mid-batch. Its events are NOT
in the project ledger, so the tail alone will under-report progress — read the
lane's own ledger (`SMITHY_LANE=<name> ledger.sh tail`) before concluding a
task never ran, then merge or abandon it based on whether its branch landed.
