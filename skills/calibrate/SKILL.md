---
name: calibrate
description: View and edit smithy's model/effort routing for this project, interactively like /config. Use when asked to "calibrate", "change smithy models", "use opus for review", "smithy config", or to see which model each pipeline role uses.
---

# Calibrate — Routing Config Editor

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/memory.md` first.
If `docs/smithy/` is missing, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.

The project routing config is `docs/smithy/config.json`. It is SPARSE — it holds
only overrides; `${CLAUDE_PLUGIN_ROOT}/defaults/config.json` supplies everything
else. You are the ONLY sanctioned writer of this file.

## Process

1. **Show the current state.** Run:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh --dump`
   Present the table (role, model, effort, source) to the user.

2. **Parse one-shot arguments if given.** Accept `role=model/effort` pairs,
   e.g. `/smithy:calibrate review=sonnet/medium testing=haiku/low`. Validate:
   roles ∈ {research, planning, implementation, review, debugging, testing,
   mechanical}, model ∈ {opus, sonnet, haiku, inherit}, effort ∈ {low, medium,
   high, max}. Invalid input → show what's wrong, don't write anything.
   If valid, skip to step 5.

3. **Ask what to change.** Use AskUserQuestion (multiSelect): which roles to
   change, plus "gates", "testing", and "implementation" as extra options. If
   the user came with a natural-language request ("use opus for review",
   "always TDD"), map it directly and confirm instead of re-asking.

4. **Per selected item, ask the new value.** One AskUserQuestion per role with
   model options (opus / sonnet / haiku / inherit) and effort options (low /
   medium / high / max); mark the current value. For "gates":
   `pause_between_phases` and `auto_fix_review_findings` (true/false). For
   "testing": `skip` subset of [ring-test, wield, proof, hone]. For
   "implementation": `tdd` ∈ {ask, always, never} — controls whether forge
   dispatches the `jigsmith` (TDD, RED→GREEN evidence) or the plain `forger`;
   see `/smithy:jig` for the trade-off table. For "review_panel":
   `auto | always | never` — whether the guild panel fires at end-of-forge
   (auto/always) or is skipped (never); it is the costliest smithy operation.

5. **Merge-write only the changed keys** into `docs/smithy/config.json`,
   preserving all existing keys (including unknown ones — warn but never
   delete them). Never write keys whose value equals the plugin default —
   the file stays sparse. Keep `smithy_config_version` unchanged.

6. **Verify and echo.** Re-run `routing.sh --dump` and show the new effective
   table. The changed rows must now read `project` in the source column — if
   one doesn't, say so and investigate; do not claim success.

7. **Log.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append calibrate <job-or-'-'> config <STATUS> docs/smithy/config.json`
   with STATUS=DONE.

## Rules

- Effort is prompt-level guidance (an injected banner per
  `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`), not an API parameter. If
  the user expects an API knob, tell them honestly.
- `inherit` means: omit the model parameter at dispatch; the agent's
  frontmatter default applies.
- Never edit `defaults/config.json` in the plugin — project overrides only.
