---
name: assay
description: Research and requirements analysis before planning — explores the codebase, converts every would-be assumption into a question or recommendation, writes a spec. Use when asked to "assay", "research this feature", "investigate before building", "write a spec", or as the first phase of the smithy pipeline.
---

# Assay — Research & Spec

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/memory.md` first.
If `docs/smithy/` is missing, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.
Pick a kebab-case job slug from the request; log:
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append assay <slug> spec STARTED -`

Resolve your own effort: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh research`
— apply that effort level to your exploration and thinking in this skill.

## Process

1. **Restate the request** in one sentence. If your restatement could be wrong,
   ask before proceeding.

2. **Surface assumptions — the core of this skill.** List EVERY assumption you
   would otherwise silently make (scope, behavior, edge cases, non-goals,
   compatibility). For each one either:
   - ask the user (AskUserQuestion, batched, most load-bearing first), or
   - state an explicit recommendation with reasoning and get confirmation.
   Nothing proceeds on a silent guess.

3. **Explore the codebase.** Existing patterns to reuse, similar features,
   affected files, constraints (framework, style, test conventions). Every
   finding cites `file:line`. For broad file inventories, you may dispatch a
   `mechanical`-routed general agent that returns paths only (see
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`).

4. **Write `docs/smithy/jobs/<slug>/spec.md`:**

   ```markdown
   # Spec — <title>
   ## Goal
   ## Constraints
   ## Findings (with evidence)
   - <finding> — file:line
   ## Resolved questions
   - Q → A (who resolved: user | recommended+confirmed)
   ## Open questions (MUST be empty to exit)
   ## Out of scope
   ```

5. **Log decisions.** Each user-resolved ambiguity gets a ≤3-line entry in
   `docs/smithy/decisions.md`.

6. **Update memory.** STATE.md (active job, phase ASSAY, next step);
   `ledger.sh append assay <slug> spec DONE jobs/<slug>/spec.md`.

## Exit criteria

- "Open questions" section is EMPTY — every blocking question was resolved.
- Every finding has file:line evidence.

Handoff: "Spec at `docs/smithy/jobs/<slug>/spec.md` — run `/smithy:blueprint` to plan."
