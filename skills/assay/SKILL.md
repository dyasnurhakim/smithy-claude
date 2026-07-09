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

## Anti-pattern: "This request is too clear to need a spec"

Every job goes through assay — a rename, a config change, a one-endpoint
feature. "Clear" requests are where unexamined assumptions do the most damage,
because nobody expects them there. For a genuinely trivial job the spec is
five lines and costs two minutes; for a job that only LOOKED trivial, those
two minutes are the cheapest save available. The spec can be short. It cannot
be skipped.

## Checklist (create a todo per item)

1. Restate the request; confirm the restatement
2. Enumerate every would-be assumption → question or recommendation
3. Explore the codebase; findings with file:line evidence
4. Write spec.md; open-questions section empty
5. Log decisions; update STATE.md + ledger; hand off

## Process

1. **Restate the request** in one sentence. If your restatement could be
   wrong in any way that changes the work, ask before proceeding.

2. **Surface assumptions — the core of this skill.** Enumerate EVERY
   assumption you would otherwise silently make. Sweep these categories:
   - **Scope**: what's in, what's out, what "done" means
   - **Behavior**: happy path, edge inputs, error handling, empty states
   - **Data**: shapes, sources, migrations, backwards compatibility
   - **Non-functionals**: performance, security, auth, i18n — only where the
     request plausibly touches them (no invented requirements)
   - **Environment**: versions, deployment target, feature flags
   For each assumption, either:
   - ask the user — AskUserQuestion, batched, most load-bearing first,
     recommended answer marked, or
   - state an explicit recommendation with reasoning and get confirmation.
   Nothing proceeds on a silent guess. If the user says "you decide", that IS
   a resolution — record it as `recommended+confirmed` in the spec.

3. **Explore the codebase.** What exists that this job touches or should
   reuse: similar features, established patterns, test conventions, affected
   files, constraints. Every finding cites `file:line`. **Use the user's
   configured tools first** (using-smithy rule 7): a code-graph tool named
   in their CLAUDE.md/rules (graphify, understand-anything) beats raw grep
   for structure questions; their memory tool (claude-mem) answers "have we
   done this before?". Tools not in their configuration stay untouched.
   For broad file inventories, dispatch a `mechanical`-routed general agent
   that returns paths only (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`).
   Prefer reusing an existing pattern over inventing one — name the pattern
   you'd reuse and where it lives.

4. **Write `docs/smithy/jobs/<slug>/spec.md`:**

   ```markdown
   # Spec — <title>
   ## Goal
   <one paragraph: what exists after this job that didn't before>
   ## Constraints
   <framework, style, compatibility, non-functionals that apply>
   ## Findings (with evidence)
   - <finding> — file:line
   ## Resolved questions
   - Q → A (resolved by: user | recommended+confirmed)
   ## Open questions (MUST be empty to exit)
   ## Out of scope
   <explicitly named non-goals — the assumptions you were told NOT to build>
   ```

5. **Log decisions.** Each user-resolved ambiguity gets a ≤3-line entry in
   `docs/smithy/decisions.md` (decision + why). Update STATE.md (active job,
   phase ASSAY, next step); `ledger.sh append assay <slug> spec DONE jobs/<slug>/spec.md`.

## Red flags — these thoughts mean STOP

| Thought | Reality |
|---|---|
| "The user obviously means X" | Obvious-to-you is where wrong builds come from. One question now beats a rebuilt feature later. |
| "I'll note the ambiguity in the spec and move on" | An open question in the spec is a landmine in the plan. Resolve it or the skill doesn't exit. |
| "Similar code probably exists, I'll assume the pattern" | Grep is cheaper than assuming. Find it, cite it, or state there's no precedent. |
| "Asking too many questions looks incompetent" | Batched, well-formed questions with recommendations look like exactly what they are: rigor. |
| "The spec is a formality, the plan is what matters" | The plan inherits every hole in the spec, and briefs inherit the plan's. Holes compound. |

## Exit criteria

- "Open questions" section is EMPTY — every blocking question was resolved.
- Every finding has file:line evidence.
- The user has seen (or explicitly waived reviewing) the spec.

Handoff: "Spec at `docs/smithy/jobs/<slug>/spec.md` — run `/smithy:blueprint` to plan."
