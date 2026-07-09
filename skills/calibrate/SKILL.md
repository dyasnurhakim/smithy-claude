---
name: calibrate
description: "View/edit model+effort routing, TDD default, gates, review panel — probes model availability before writing. Triggers: 'calibrate', 'smithy config'."
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
   mechanical}, model ∈ {fable, opus, sonnet, haiku, inherit}, effort ∈ {low, medium,
   high, max}. Invalid input → show what's wrong, don't write anything.
   If valid, skip to step 5.

3. **Ask what to change.** Use AskUserQuestion (multiSelect): which roles to
   change, plus "gates", "testing", and "implementation" as extra options. If
   the user came with a natural-language request ("use opus for review",
   "always TDD"), map it directly and confirm instead of re-asking.

4. **Per selected item, ask the new value.** One AskUserQuestion per role with
   model options (fable / opus / sonnet / haiku / inherit — fable is the Mythos-class tier above opus; every model choice is probed in step 5 before it is written) and effort options (low /
   medium / high / max); mark the current value. For "gates":
   `pause_between_phases` and `auto_fix_review_findings` (true/false). For
   "testing": `skip` subset of [ring-test, wield, proof, hone]. For
   "implementation": `tdd` ∈ {ask, always, never} — controls whether forge
   dispatches the `jigsmith` (TDD, RED→GREEN evidence) or the plain `forger`;
   see `/smithy:jig` for the trade-off table. For "review_panel":
   `auto | always | never` — whether the guild panel fires at end-of-forge
   (auto/always) or is skipped (never); it is the costliest smithy operation.

5. **Probe model availability BEFORE writing.** Model access varies by
   account and changes over time (e.g. `fable` moved from subscription
   access to usage-credit access) — a config pointing at an unavailable
   model breaks every dispatch for that role. For EACH model value being
   newly set (once per distinct model, `inherit` exempt):
   - Dispatch a minimal probe: Agent tool, `model` = the candidate, prompt
     exactly: "Effort: LOW. Reply with the single word: ok". No files, no
     tools needed.
   - Probe returns → model is available; proceed.
   - Dispatch errors/rejects → do NOT write that role's change. Tell the
     user which model failed the probe and keep the current value; suggest
     the nearest available tier (fable→opus, opus→sonnet).
   Never skip the probe on the assumption a model "should" be available —
   that is exactly the assumption this step exists to kill.

6. **Merge-write only the changed keys** into `docs/smithy/config.json`,
   preserving all existing keys (including unknown ones — warn but never
   delete them). Never write keys whose value equals the plugin default —
   the file stays sparse. Keep `smithy_config_version` unchanged.

7. **Verify and echo.** Re-run `routing.sh --dump` and show the new effective
   table. The changed rows must now read `project` in the source column — if
   one doesn't, say so and investigate; do not claim success.

8. **Log.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append calibrate <job-or-'-'> config <STATUS> docs/smithy/config.json`
   with STATUS=DONE.

## Rules

- Effort is prompt-level guidance (an injected banner per
  `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`), not an API parameter. If
  the user expects an API knob, tell them honestly.
- `inherit` means: omit the model parameter at dispatch; the agent's
  frontmatter default applies.
- Never edit `defaults/config.json` in the plugin — project overrides only.
