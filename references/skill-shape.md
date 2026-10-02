# Skill Shape — the layout every smithy SKILL.md follows

One layout for every skill, so each one reads the same way, starts the same
way, and ends with proof. This file is for people writing or changing a
skill; skills themselves do not need to read it at run time.

```
┌──────────────────────────────────────────────────────────┐
│ frontmatter: name + quoted description (with triggers)    │
│ # Title — one line on what it does                        │
│ ## Start          one start.sh call + what to read        │
│ ## Needs          what must exist · what to do if missing │
│ ## Steps          numbered, each with → verify:           │
│ ## Done when      checklist, each item provable           │
│ ## Output         files written + the Next: line          │
│ ## Red flags      (optional) thoughts that mean STOP      │
└──────────────────────────────────────────────────────────┘
```

## Rules for each part

**Start** — always the same two lines:

```markdown
## Start
1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh <skill> <auto|new>` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`
   [+ `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` only if this skill dispatches agents]
   [+ anything else this skill truly needs].
```

`auto` for skills that continue a job (blueprint, forge, inspect, temper,
test skills, guild, handover). `new` for skills that start their own small
job (strike, anneal, jig, burnish, pattern, commission). assay passes the
feature slug it chose.

**Needs** — a table. Every row says what happens when the thing is missing.
A skill must never stop only because another skill has not run first:

| Needs | If it exists | If it is missing |
|---|---|---|
| e.g. spec.md | use it | ask ≤5 questions, write a mini spec, continue |

Only things that are truly part of the job may stop the skill (no running
app for QA, no thresholds for a load test). Then say exactly what is missing
and how to provide it.

**Lookup** — if the skill benefits from memory/graph/docs tools, it says
which (creed §10) in one line inside Steps. Never name a tool as required.

**Steps** — numbered. Each step ends with `→ verify: <check>`. Use the
user's words and the creed's terms. Keep each step short; link to a
reference file instead of repeating it.

**Done when** — a checklist. Every item can be proven with output, a
`file:line`, or a ledger line. Creed §8: before stopping, tick each item
with its proof, and list anything not done.

**Output** — the files written (full paths under the job folder) and ONE
last line in this exact form:

```
Next: /smithy:<skill> — <why, in a few words>
```

or, when nothing follows: `Next: none — <what the user may want to check>`.

## Shared conventions

| Thing | Convention |
|---|---|
| Job slug | from start.sh: active job, or `<skill>-<YYYY-MM-DD>[-N]`, or a kebab-case feature name |
| Ledger phase | the skill's own name (`jig`, `strike`, `ring-test`…); reserved: `gate` |
| Base sha | set ONCE per job (`review-package.sh record-base`). Standalone reviews pass `--base <ref>` and never touch STATE |
| Fix rounds | always `implementation.max_fix_cycles` from config — never a number written in a skill |
| Fixes from a review or QA | go to `/smithy:strike` (no plan needed), not to forge |
| Reports | open with the envelope (`${CLAUDE_PLUGIN_ROOT}/references/envelope.md`), first body line `Status:` |
| Personas | named by file path (`${CLAUDE_PLUGIN_ROOT}/references/personas/masters/qa.md`) |
| Models | named by routing role (`review`, `implementation`), never a model name |
| Size | SKILL.md ≤ 300 lines; description in quotes |
| Run line | apps to run for QA/load tests: `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md` § Run line |
| Voice | creed §9: simple English, short, with a picture where it helps |
