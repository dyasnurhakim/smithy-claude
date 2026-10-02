# Smithy Memory — Full Reference

**This is the full reference:** where memory lives, first-time setup, lanes,
config layers. For everyday use, skills read `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`
instead. Read this file only to set up or move memory (calibrate, exit 3
from start.sh) or to work with lanes.

Each project has one memory folder. In this file it is `<memory>`; scripts
call it `$SMITHY_MEM`. It may be inside the repo or outside it. Every smithy
path is written relative to it. `start.sh` (step 1 of every skill) finds it
and prints it; to print it yourself:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh mem
```

**Never hard-code `docs/smithy`.** Many projects clean, regenerate or
gitignore `docs/`, which would quietly wipe the ledger in the middle of a job.

## Location

`paths.sh` picks the memory folder by the first rule that matches:

| # | Rule | Set by |
|---|---|---|
| 1 | `$SMITHY_MEM_DIR` env var | the user, per session |
| 2 | `<repo>/.smithy-path` — a one-line pointer file | `init-memory.sh --at <dir> --pointer` |
| 3 | `$SMITHY_HOME/projects.tsv` registry (outside the repo) | `init-memory.sh --external`, `paths.sh set-mem` |
| 4 | `<repo>/docs/smithy/` when it already exists | old projects — keeps working untouched |
| 5 | global `memory.location`: `repo` \| `external` | `/smithy:calibrate` (global config only — a project config cannot say where the project config lives) |

`$SMITHY_HOME` = the `$SMITHY_HOME` env var → `$XDG_CONFIG_HOME/smithy` → `~/.smithy`.

`bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh --dump` shows the folder and
which rule chose it. Rules 1–4 are pure bash, so the guard hook can find
paths without starting an interpreter.

### First-time setup (bootstrapping)

`start.sh` runs `init-memory.sh` for you the first time. It is safe to run
again (it changes nothing that exists).

**Exit 3 means nobody has decided where memory lives, and the script will
not guess.** Ask the user, then run it again with their answer:

| Choice | Flag | When it fits |
|---|---|---|
| in the repo | `--in-repo` | memory should be reviewed and committed with the code |
| outside the repo | `--external` | the repo cleans, regenerates or gitignores `docs/` |
| a folder they name | `--at <dir>` | a shared drive, a notes repo next to this one, a monorepo corner |

Add `--pointer` to also write `<repo>/.smithy-path`, so a fresh clone on
another machine finds the same folder (the registry is per machine). Add
`--global-default repo|external` to stop being asked in new projects.

Then run `start.sh` again — the folder has changed.

## File map

```
<memory>/
├── STATE.md          THE index. At most 40 lines. Overwritten, never appended.
├── config.json       this project's config overrides (sparse; /smithy:calibrate writes it)
├── ledger.md         append-only event log — write ONLY with scripts/ledger.sh
├── decisions.md      append-only decision log, ≤3 lines per entry
├── DESIGN.md         design rules, when /smithy:pattern has run
├── design/previews/  pattern's HTML previews
├── personas/         test personas, when /smithy:commission has run
├── lanes/<name>/     per-lane STATE.md + ledger.md + decisions.md (see § Lanes)
│   └── .merged/      lanes already folded back in, kept for audit
└── jobs/<slug>/      one folder per job; slug from start.sh
    ├── spec.md              assay
    ├── plan.md              blueprint (or a mini plan from strike/forge)
    ├── briefs/task-N.md     one brief per task
    ├── reports/             forge-report.md, review.md, strike-report.md, rca-*.md,
    │                        test-*.md, temper-summary.md, guild-verdict.md/json,
    │                        burnish-report.md/json. Per-task task-N-impl.md files
    │                        are scratch: forge folds them into forge-report.md and
    │                        deletes them.
    │   └── raw/             long command output, TDD logs (<task>-tdd.log)
    └── handoff.md           handover (overwritten each time)
```

Guard tokens (`.git-grant`, `.push-once`, `.destructive-once`) also live
here. When memory is in the repo, they are gitignored.

## Lanes — parallel work without two writers on one file

The memory folder is one per PROJECT, tied to the MAIN worktree. That is on
purpose: a ledger that quietly splits per worktree is worse than a shared
one. But it means two units of work running at once would append to the
same `ledger.md` and overwrite the same `STATE.md` (which has room for one
active job).

A **lane** gives each unit its own copy of just the files that change:

| Per lane | Project-wide (never per lane) |
|---|---|
| `STATE.md`, `ledger.md`, `decisions.md` | `config.json`, `jobs/`, `personas/`, `DESIGN.md`, guard tokens |

Config is project-wide because a lane is a unit of work, not a different set
of preferences. Guard tokens are project-wide because permission belongs to
the user and the project — a lane must never be able to give itself a
commit grant.

Which lane am I in? First match wins (pure bash, so the guard hook stays fast):

| # | Rule | Set by |
|---|---|---|
| 1 | `$SMITHY_LANE` env var | a dispatcher pinning one agent to one lane |
| 2 | `<this worktree>/.smithy-lane` marker file | `worktree.sh create`, automatically |
| 3 | none → state lives in `<memory>` itself | normal one-at-a-time work |

Lane names use only `[A-Za-z0-9._-]`, never start with a dot, never contain
`..` — the name becomes part of a path. A bad name is IGNORED (falls back to
the shared folder); it is never "cleaned up" into a different lane.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh start <name> [--worktree <path>] [--job <slug>]
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh list | current | status
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh merge <name>      # fold into the project state
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh merge-all         # after a whole batch lands
bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh abandon <name>    # work that was rolled back
bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh where           # which file am I appending to?
```

**Reads are merged; writes never are.** Inside a lane, `ledger.sh tail`
shows the lane's events mixed with the project's, in time order. So a
controller resuming after compaction sees the whole history, not only its
slice, and makes the same resume decision it would have made without lanes.
Appends still go only to the lane.

**Merging** is a time-sorted union. Every ledger line starts with an ISO
timestamp and lines are only ever appended, so joining lanes is a sort, not
a three-way merge: no conflicts, no lost events, and each lane keeps its own
order within a tied minute. `merge` also appends the lane's `decisions.md`,
refreshes the `Last event` line in the project `STATE.md`, and archives the
lane under `lanes/.merged/`. It does NOT rewrite `Phase` or `Next step` —
those carry meaning and belong to the controller.

**Merge or abandon every lane before the job ends.** An unmerged lane is
work the next session cannot see — and the recovery rule tells it to trust
the ledger over memory. `worktree.sh remove` reports unmerged lanes instead
of merging them: a removed checkout can be thrown away; an event log cannot.

## Config layers

Three layers merge key by key, lowest first:

| Layer | File | Applies to |
|---|---|---|
| defaults | `${CLAUDE_PLUGIN_ROOT}/defaults/config.json` | ships with the plugin; never edit per project |
| global | `$SMITHY_HOME/config.json` | **every project** on this machine |
| project | `<memory>/config.json` | this project only |

Read any key, and where its value came from:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh get    implementation.tdd
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh source implementation.tdd   # -> defaults|global|project
bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh --dump                     # routing table + layers
```

Keys the pipeline reads most:

| Key | Values | Read by |
|---|---|---|
| `implementation.tdd` | ask \| always \| never | forge (choose the builder) |
| `implementation.tdd_level` | minimal \| balanced \| max | jig → the brief lines |
| `implementation.tdd_commits` | clean (default) \| stages | jig → the brief lines; the final review checks the matching proof |
| `implementation.max_fix_cycles` | number (default 2; 0 = never auto-fix) | every skill with fix rounds, `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §6 |
| `gates.*`, `testing.skip`, `review_panel` | see `/smithy:calibrate` | smithy, temper, guild, inspect |

Old values for the commits setting are still read: `git` = stages, `local` = clean.

`/smithy:calibrate` is the only skill that writes the global and project
layers. Both stay SPARSE: they hold only what differs from the layer below.

## STATE.md format (exact — keep all six lines, ≤40 lines total)

```markdown
# Smithy State
- Active job: jobs/<slug>/
- Phase: ASSAY|BLUEPRINT|FORGE|STRIKE|ANNEAL|TEMPER|GUILD|IDLE (task N of M)
- Base sha: <sha|none>
- Last event: <ISO-ts> <skill> <unit> <STATUS>
- Blockers: <text|none>
- Next step: <one concrete action, with its file path>
```

**Base sha is the JOB's base, set ONCE** when the job starts
(`review-package.sh record-base` — by blueprint, or by a skill that starts
its own job). Never per task: the final review diffs base → HEAD, so a
moved base hides earlier tasks. A standalone review, or a small job running
while another job is active, saves its own start sha (`git rev-parse HEAD`)
and passes `--base <sha>` to `review-package.sh build` — it never
overwrites STATE's base.

## Ledger

One line per event, written only with
`ledger.sh append <skill> <slug> <unit> <STATUS> <path>` — the phase column
is the skill's own name:

```
2026-07-06T10:22Z | forge | user-auth | task-2 | DONE | jobs/user-auth/reports/task-2-impl.md
```

Statuses: `STARTED DONE DONE_WITH_CONCERNS NEEDS_CONTEXT BLOCKED APPROVED REJECTED PASS FAIL PARTIAL`

Paths in the ledger are relative to `<memory>`, so moving the memory folder
does not break the history.

## Who writes what

| Who | Reads | Writes |
|---|---|---|
| `start.sh` (step 1 of every skill) | STATE.md, `ledger.sh tail`, `lane.sh list` | `jobs/<slug>/reports/`, one `STARTED` ledger line |
| assay | — | `jobs/<slug>/spec.md`, decisions.md (settled questions), STATE.md |
| blueprint | spec.md | plan.md, briefs/task-*.md, decisions.md, the job base, STATE.md |
| forge / jig | plan.md, briefs, config `implementation.*` | ledger per task, STATE.md, decisions.md (TDD choice), forge-report.md, lane merges after a parallel batch. Agents write `reports/task-N-impl.md` (and `reports/raw/` TDD logs). One review of the whole job at the end — no per-task review |
| strike | its mini plan | plan.md, strike-report.md, ledger |
| inspect | a brief + the review package | `jobs/<slug>/reports/review.md` (the inspector writes it; the controller adds `## Controller notes`), ledger verdict |
| anneal | the failure context | decisions.md (fix decision), ledger (the annealer writes `rca-*.md`) |
| test skills + temper | plan.md, stack-detect output | reports/test-*.md, temper-summary.md, ledger |
| guild | the review package, personas/ | guild-verdict.md + .json, ledger |
| pattern | spec/README, an existing DESIGN.md | DESIGN.md, design/previews/, decisions.md, ledger |
| burnish | DESIGN.md, a past burnish report | burnish-report.md + .json, screenshots, ledger |
| commission | the codebase, the user | personas/, ledger |
| handover | STATE.md, ledger, reports | handoff.md, STATE.md |
| calibrate | all three config layers | global and/or project config.json, ledger |
| smithy (orchestrator) | all of the above | STATE.md at every phase boundary, ledger gate lines |

## Keep it lean

- STATE.md ≤ 40 lines. Ledger entries are one line. decisions.md entries ≤ 3 lines.
- Write only at: skill start, end of a unit, phase boundary. Never mid-task.
- Memory files hold **paths to files, never their contents**.

## Recovery rule

Chat memory does not survive compaction or a dead session. **Trust
STATE.md, the ledger and `git log` over your own recollection.** On resume:

```
start.sh ──▶ read STATE.md ──▶ ledger.sh tail ──▶ lane.sh list ──▶ git log --oneline <base>..HEAD ──▶ resume
             (start.sh prints all three, including UNMERGED LANES)
```

Resume at the first unit with no `DONE`/`APPROVED` ledger line. Units marked
done are never dispatched again.

An unmerged lane means an earlier session died mid-batch. Its events are NOT
in the project ledger, so the tail alone shows less progress than was made.
Read the lane's own ledger (`SMITHY_LANE=<name> ledger.sh tail`) before
deciding a task never ran. Then merge or abandon the lane, depending on
whether its branch landed.
