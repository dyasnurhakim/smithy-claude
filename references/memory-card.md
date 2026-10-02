# Smithy Memory — Quick Card

All you need to use memory. The full rules (where memory lives, lanes,
config layers) are in `memory.md`; read that only when you set up or move
memory, or work with lanes.

## Start every skill with one call

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh <skill> [auto|new|<slug>]
```

It finds (or creates) the memory folder, reads STATE.md, picks the job
slug, and logs `STARTED`. Read its summary; use the `memory:` and `job:`
paths it prints. Exit 3 = ask the user where memory should live, run the
`init-memory.sh` line it shows, run start.sh again. Exit 4 = not a git repo.

## Where things are

```
<memory>/
├── STATE.md       the index: active job, phase, base, next step (≤40 lines, overwrite)
├── ledger.md      event log — write ONLY with ledger.sh
├── decisions.md   decision log, ≤3 lines per entry
├── DESIGN.md      design rules (from /smithy:pattern), if any
├── personas/      test personas (from /smithy:commission), if any
└── jobs/<slug>/   spec.md · plan.md · briefs/task-N.md · reports/ · handoff.md
```

## Write rules

- Ledger: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append <skill> <slug> <unit> <STATUS> <path>`
  — phase name = the skill's own name; `gate` is the one reserved extra
  phase (approval gate lines). Paths relative to memory.
- Statuses: `STARTED DONE DONE_WITH_CONCERNS NEEDS_CONTEXT BLOCKED APPROVED REJECTED PASS FAIL PARTIAL`
- Write only at: start, end of a unit, phase boundary. Memory holds paths,
  never file contents.
- STATE.md keeps exactly these lines (rewrite them, never append):

```markdown
# Smithy State
- Active job: jobs/<slug>/
- Phase: ASSAY|BLUEPRINT|FORGE|STRIKE|ANNEAL|TEMPER|GUILD|IDLE (task N of M)
- Base sha: <sha|none>      ← the JOB's base, set once by record-base
- Last event: <ISO-ts> <skill> <unit> <STATUS>
- Blockers: <text|none>
- Next step: <one concrete action, with its file path>
```

## Run line

Skills that need a running app (wield, proof, guild, burnish, temper) read
the LATEST line starting `run:` in `<memory>/decisions.md`, in the form
`run: <start command> | url: <url>`. Missing → ask the user once, then
append that line.

## After compaction or a resume

Trust STATE.md + `ledger.sh tail` + `git log` over your memory. Resume at
the first unit without a `DONE`/`APPROVED` line. Never redo finished units.
If start.sh shows UNMERGED LANES, read that lane's ledger
(`SMITHY_LANE=<name> bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail`)
before you decide a task never ran; then merge or abandon the lane.
