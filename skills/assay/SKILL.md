---
name: assay
description: "Research → spec: explore the code, turn every assumption into a question or a recommendation, write spec.md. Building a feature starts here. Triggers: 'assay', 'research this', 'write a spec', 'new feature'."
---

# Assay — Research and Spec

An assay tests the ore before it is smelted. Here we test the request
before anything is built.

```
request ─▶ restate ─▶ list assumptions ─▶ ask / recommend ─▶ explore code ─▶ spec.md
                      (scope, behavior,    nothing rests on    every finding     open
                       data, env …)        a silent guess      has file:line     questions = 0
```

| Work | Lane |
|---|---|
| A feature, new behavior, anything spec-shaped | **assay** → `/smithy:blueprint` → `/smithy:forge` |
| Small known changes (copy, config, review/QA findings) | `/smithy:strike` |
| A bug whose cause is unknown | `/smithy:anneal` |

## Start

1. Get the request first (Needs). From it pick a kebab-case slug for the
   feature (`user-auth`), then
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh assay <slug>` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`.
3. Effort: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh research` — think at that effort.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| The request (before start.sh — the slug comes from it) | from the user | ask what to build, in one question |
| An earlier spec (`jobs/<slug>/spec.md`) | revise it; keep its resolved answers | start a new one |
| Code to explore | the repo | new project: say so; findings say "no precedent" and cite the empty search |
| No other active job | continue | start.sh shows another active job: ask whether this job becomes the active one (the other stays on disk) |

## Steps

1. **Restate** the request in one sentence. If your restatement could be
   wrong in a way that changes the work, ask before going on.
   → verify: the user confirmed it, or you said why it cannot change the work.

2. **Surface assumptions — the core of this skill.** List EVERY assumption
   you would otherwise make silently. Sweep these areas:
   - **Scope:** what is in, what is out, what "done" means.
   - **Behavior:** happy path, edge input, errors, empty states.
   - **Data:** shapes, sources, migrations, backward compatibility.
   - **Non-functional:** speed, security, auth, i18n — only where the
     request really touches them. No invented requirements.
   - **Environment:** versions, deploy target, feature flags.

   For each one, either ask the user (AskUserQuestion, batched, most
   important first, your recommended answer marked) or state a
   recommendation with its reason and get it confirmed. "You decide" is an
   answer: record it as `recommended+confirmed`.
   → verify: every assumption sits in Resolved questions with who resolved it.

3. **Lookup** (creed §10, once) — memory: "did we build or reject this
   before?"; graph: structure and callers of the area; docs: library APIs
   for the pinned version. None installed → Grep/Read, say so in one line.
   → verify: each lead you use is checked in the code and cited (`claude-mem #ID`, `file:line`), or you wrote "no lookup tool".

4. **Explore the code.** What does this job touch or reuse: similar
   features, patterns, test conventions, affected files, limits. Every
   finding cites `file:line`. Prefer reusing a pattern over inventing one —
   name it and where it lives. For a big file inventory, dispatch a general
   agent on role `mechanical` that returns paths only
   (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §1–2).
   → verify: every finding has a `file:line`.

5. **Write** `<memory>/jobs/<slug>/spec.md`:

   ```markdown
   # Spec — <title>
   ## Goal
   <one paragraph: what exists after this job that did not before>
   ## Constraints
   <framework, style, compatibility, non-functionals that apply>
   ## Findings (with evidence)
   - <finding> — file:line
   ## Resolved questions
   - Q → A (resolved by: user | recommended+confirmed)
   ## Open questions (MUST be empty to finish)
   ## Out of scope
   <named non-goals — the things you were told NOT to build>
   ```
   → verify: the Open questions section is empty.

6. **Show the spec** — path plus a summary of at most 5 lines. Revise until
   the user approves it or waives the review. In a pipeline, the
   orchestrator's gate does this step.
   → verify: the user said yes (or waived), or the orchestrator has the path.

7. **Log** — each question the user resolved → a ≤3-line entry in
   `<memory>/decisions.md` (decision + why). STATE.md: active job
   `jobs/<slug>/`, Phase ASSAY, next step `/smithy:blueprint`.
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append assay <slug> spec DONE jobs/<slug>/spec.md`
   → verify: `ledger.sh tail 1` shows the DONE line.

## Done when

- [ ] the restatement was confirmed (or cannot change the work, with the reason)
- [ ] every assumption is resolved, with who resolved it
- [ ] every finding has `file:line` evidence
- [ ] Open questions is empty
- [ ] the user approved or waived the spec (or the pipeline gate holds it)
- [ ] decisions.md entries written; STATE.md updated; ledger DONE line written

## Output

`<memory>/jobs/<slug>/spec.md` · entries in `<memory>/decisions.md`.

`Next: /smithy:blueprint — turn the spec into tasks and briefs`

## Red flags

| Thought | Reality |
|---|---|
| "This feature is too clear to need a spec" | Clear requests are where hidden assumptions hurt most. For a truly small job the spec is five lines and two minutes. Short, never skipped. (Small KNOWN changes go to strike instead.) |
| "The user obviously means X" | Obvious-to-you is where wrong builds come from. One question now beats a rebuilt feature. |
| "I'll note the open question in the spec and move on" | An open question in the spec is a trap in the plan. Resolve it, or the skill does not finish. |
| "Similar code probably exists, I'll assume the pattern" | A search is cheaper than a guess. Find it and cite it, or say there is no precedent. |
| "Many questions look incompetent" | Batched questions with recommendations look like what they are: care. |
| "The spec is a formality, the plan matters" | The plan inherits every hole in the spec, and the briefs inherit the plan's. |
