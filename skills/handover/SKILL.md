---
name: handover
description: Write a session handoff so the next session or a teammate resumes with zero re-discovery. Use when asked to "handover", "handoff", "save session", "write a summary for next time", or before ending a long working session.
---

# Handover — Session Handoff

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/memory.md` first.
If `docs/smithy/` is missing, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.

## Process

1. **Gather evidence — never write from recollection.** Run and read:
   - `docs/smithy/STATE.md`
   - `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh tail 30`
   - `git status --short` and `git log --oneline -10`
   - The latest report files referenced by the ledger (paths only if long).

2. **Determine the active job.** From STATE.md. If no active job, ask the
   user what this handoff should cover (ad-hoc work is written to
   `docs/smithy/jobs/adhoc-<YYYY-MM-DD>/handoff.md`).

3. **Write `docs/smithy/jobs/<slug>/handoff.md`** (overwrite previous) using
   EXACTLY this template:

   ```markdown
   # Handoff — <job> — <ISO date>
   ## What We Are Building
   ## What WORKED (with evidence)
   - <claim> — evidence: <ledger line | report path | command output>
   ## What Did NOT Work (and why)
   ## Not Tried Yet
   ## Current State of Files
   | Path | State |
   ## Decisions Made
   - <from docs/smithy/decisions.md — reference, don't duplicate>
   ## Blockers
   ## Exact Next Step
   <one concrete action, with the artifact path it starts from>
   ## Environment
   <run commands, env vars needed, service URLs — only what's needed to resume>
   ```

   Every claim in "What WORKED" MUST cite a ledger line, a report path, or
   verbatim command output. A claim you cannot evidence goes under "Not Tried
   Yet" or is dropped.

4. **Sync STATE.md.** Its `Next step` line must match the handoff's "Exact
   Next Step" verbatim. Update `Last event` too.

5. **Revoke git grants.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/guard.sh revoke`
   — a handoff ends the working session; the next session re-earns
   authorization at its own gate.

6. **Log.** `ledger.sh append handover <job> handoff DONE jobs/<slug>/handoff.md`

7. **Tell the user:** the handoff path, plus: "Next session: run /smithy —
   it resumes from STATE.md and the ledger automatically."

## Rules

- No unevidenced claims. "Tests pass" without a ledger PASS line or pasted
  output does not go in the handoff.
- Paths, not content: reference reports by path; never inline them.
- The handoff is for a reader with ZERO context — spell out the job goal in
  one sentence even if it feels obvious.
