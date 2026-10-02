---
name: inspect
description: "Code review with two verdicts (does it meet the spec? is the code good?) — every finding has proof, a severity reason and a confidence. Reviews a branch, a commit range or uncommitted changes. Triggers: 'inspect', 'review this change', 'code review'."
---

# Inspect — Two-Verdict Review

```
what should it do? (brief) ──┐
                             ├──▶ inspector ──▶ Verdict 1 spec · Verdict 2 quality
what changed? (BASE..TARGET) ┘                 ──▶ you judge the findings ──▶ user
```

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh inspect auto` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| What to review | from the user or the caller | ask: a branch, a commit range, or uncommitted changes? |
| A base | the caller's job base (STATE.md) | standalone: ask, or recommend the merge-base with the default branch (`git merge-base HEAD origin/main`). Pass it as `--base`; never write it into STATE.md |
| What the change should do | the plan / brief | write a short brief at `jobs/<slug>/briefs/review-brief.md` from the user's words. Unclear → ask; never infer the intent silently |

## Steps

1. **Package** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh build [--base <ref>] <brief> <memory>/jobs/<slug>/reports/review-pkg.md [<report file or reports folder> | ""] [HEAD|<branch>|WORKTREE]`
   (`WORKTREE` = include uncommitted changes). To review a target with no
   report, pass "" as the report (arguments are by position).
   → verify: the script prints `package=… lines=N`.
2. **Dispatch** one `inspector` (role `review`, `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §1–2).
   Prompt = banner + paths (package, creed, report path
   `jobs/<slug>/reports/review.md`) + this line exactly:
   **"Do Not Trust the Reports — the implementers' claims are unverified.
   Verify each one against the diff and with read-only checks."**
   If TDD ran, also say the commits mode (`clean` or `stages`).
   → verify: the report exists with two verdicts.
3. **Judge the findings** (next section) before showing or acting on them.
   → verify: every High/Critical finding is confirmed, reclassified, or disputed with proof.
4. **Show the user**: both verdicts, then a findings table (severity,
   confidence, `file:line`). Do not soften severities; label low-confidence
   findings instead of dropping them.
   → verify: the user saw both verdicts and a table row for every finding.
5. **Route the fixes** —
   - Called by forge/strike/jig: hand the verdicts back; the caller owns fix
     rounds (budget: `implementation.max_fix_cycles`).
   - On its own: if `config.sh get gates.auto_fix_review_findings` is `true`,
     offer to fix Critical/High through `/smithy:strike`; otherwise list the
     findings with a recommended action each, and stop — the user decides.
   → verify: the user saw every finding, or the caller has the verdicts.
6. **Log** — `ledger.sh append inspect <slug> <unit> <APPROVED|REJECTED> <review-path>`.
   → verify: `ledger.sh tail 1` shows the inspect line.

## Judging findings

The inspector's report is input, not an order. You are the controller:

- Check "every / all / no" claims against the diff before repeating them.
- Re-rate a severity when the finding's own text undercuts it ("works, but
  could be cleaner" is not High).
- Below confidence 7 = a question to check, not a fix order.
- Wrong premise → push back with proof, and add a `## Controller notes`
  section to the review report saying why a finding was not acted on.
- The verdict follows the brief, not taste: disagreeing with an approved
  design is a note, not a REJECTED. REJECTED (quality) needs at least one
  Critical or High finding.

## Done when

- [ ] the base and target were stated (and the base was never written into another job's STATE)
- [ ] the review report has two verdicts and proof for every finding
- [ ] every Critical/High finding was confirmed or disputed with evidence
- [ ] the user saw the findings table, or the caller got the verdicts
- [ ] ledger line written

## Output

`jobs/<slug>/reports/review.md` (with `## Controller notes` if you disputed anything).

`Next: /smithy:strike — fix the confirmed findings` · or `Next: none — approved`.

## Red flags

| Thought | Reality |
|---|---|
| "The findings look right, apply them all" | Findings are checked, not obeyed. A wrong fix is now your diff. |
| "REJECTED, but the fixes are tiny — I'll do them inline" | Fixes go through strike (or the caller's fix round) so they get checked too. |
| "Drop the low-confidence findings" | Label them; the user decides what is noise. |
| "The report matches the diff, skip the checks" | Reports have been wrong before. The inspector runs the checks. |
