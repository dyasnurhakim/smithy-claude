---
name: handover
description: "Session handoff where every claim cites evidence, so the next session resumes with no re-discovery. Covers the active job, open lanes and a half-done TDD task. Triggers: 'handover', 'handoff', 'save session', 'wrap up'."
---

# Handover — Session Handoff

```
STATE.md + ledger + git + reports ──▶ handoff.md (every claim cited) ──▶ STATE "Next step" = same line
                                                                     ──▶ commit grants revoked
```

The reader of the handoff has ZERO context. Write for them.

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh handover auto` — read its summary
   (active job, phase, base, open lanes, recent events).
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| An active job | start.sh reuses its slug | start.sh made `handover-<date>`; ask the user in one question what this handoff should cover, then continue |
| Ledger / reports | cite them | cite `git log`, `git status` and command output you run now |

Nothing else must run first.

## Steps

1. **Gather evidence — never write from memory.** Run and read:
   - `<memory>/STATE.md` and `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail 30`
   - `git status --short` and `git log --oneline -10`
   - the latest reports named in the ledger (cite paths; never paste them)
   - open parallel work: the `UNMERGED LANES` part of the start.sh summary
     (or `bash ${CLAUDE_PLUGIN_ROOT}/scripts/lane.sh list`) and
     `bash ${CLAUDE_PLUGIN_ROOT}/scripts/worktree.sh list`
   - a job stopped mid-forge or mid-jig: the TDD pictures log of the task in
     progress, `<memory>/jobs/<slug>/reports/raw/task-N-tdd.log` — its last
     line says which stage (RED / GREEN / REFACTOR) the task reached.
   Lookup (creed §10, once): memory fits "what did this session decide?".
   → verify: you have the ledger tail and git output in front of you.

2. **Write `<memory>/jobs/<slug>/handoff.md`** (overwrite any old one) with
   EXACTLY this template:

   ```markdown
   # Handoff — <job> — <ISO date>
   ## What We Are Building
   <one sentence, even if it feels obvious>
   ## What WORKED (with evidence)
   - <claim> — evidence: <ledger line | report path | command output>
   ## What Did NOT Work (and why)
   ## Not Tried Yet
   ## Current State of Files
   | Path | State |
   ## Open Parallel Work
   <unmerged lanes and smithy worktrees, with the command to merge or abandon
   each (`lane.sh merge <name>` / `lane.sh abandon <name>`) — or "none">
   ## Task In Progress
   <task N, its stage from the TDD pictures log (path), and what is left — or "none">
   ## Decisions Made
   - <point to decisions.md entries; do not copy them>
   ## Blockers
   ## Exact Next Step
   <one concrete action, with the file path it starts from>
   ## Environment
   <run commands, env vars, service URLs — only what is needed to resume>
   ```

   Every claim under "What WORKED" cites a ledger line, a report path, or
   verbatim command output. A claim you cannot prove goes under "Not Tried
   Yet", or is dropped. "Tests pass" with no PASS ledger line and no output
   does not go in.
   → verify: each WORKED line has an `evidence:` part.

3. **Sync STATE.md** — its `Next step` line must match "Exact Next Step"
   word for word; update `Last event`.
   → verify: `grep '^- Next step:' <memory>/STATE.md` matches the handoff.

4. **Revoke commit grants** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh revoke`.
   A handoff ends the working session; the next session earns its own
   approval at its own gate.
   → verify: `guard.sh status` shows no grant.

5. **Log** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append handover <slug> handoff DONE jobs/<slug>/handoff.md`.
   → verify: the ledger line exists.

## Rules

- No claim without evidence. Paths, not content: name reports by path.
- Open lanes and worktrees are never cleaned up by a handover — list them;
  the next session (or the user) merges or abandons them.

## Done when

- [ ] `handoff.md` follows the template; every WORKED line cites evidence
- [ ] open lanes / worktrees and any task in progress are listed (or "none")
- [ ] STATE.md `Next step` matches the handoff word for word
- [ ] `guard.sh status` shows no grant
- [ ] ledger line written

## Output

`<memory>/jobs/<slug>/handoff.md`. Tell the user its path.

`Next: /smithy:smithy — in the next session; it resumes from STATE.md and the ledger`
