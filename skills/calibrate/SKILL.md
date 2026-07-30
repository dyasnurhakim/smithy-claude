---
name: calibrate
description: "View/edit smithy config at GLOBAL (all projects) or PROJECT scope — model+effort routing, TDD default, gates, review panel, where memory lives. Probes model availability before writing. Triggers: 'calibrate', 'smithy config'."
---

# Calibrate — Config Editor (global + per-project)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/memory.md` first.
Resolve memory first: `export SMITHY_MEM="$(bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh mem)"` —
every smithy path below is relative to it, and it need NOT be inside the repo. If that dir
does not exist, bootstrap per `${CLAUDE_PLUGIN_ROOT}/references/memory.md` § Location.

Config has **three layers**, merged per key, lowest precedence first:

| Layer | File | Scope | You may write it |
|---|---|---|---|
| defaults | `${CLAUDE_PLUGIN_ROOT}/defaults/config.json` | ships with the plugin | **NEVER** |
| global | `$SMITHY_HOME/config.json` | every project on this machine | yes (`--global`) |
| project | `$SMITHY_MEM/config.json` | this project only | yes (default) |

You are the ONLY sanctioned writer of the global and project layers. Both stay
SPARSE — they hold only what differs from the layer below.

## Process

1. **Show the current state.** Run:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh --dump`
   Present the table (role, model, effort, source). The SOURCE column names the
   layer that supplied each value — `defaults`, `global`, or `project`, with
   `(tier)` when a tier name expanded and `(translated)` when a cross-harness
   value was mapped by tier. The header also shows the resolved memory dir and
   how it was resolved.

2. **Parse one-shot arguments if given.** Accept `role=model/effort` pairs,
   e.g. `/smithy:calibrate review=sonnet/medium testing=haiku/low`. Also accepts
   `--global` (or `scope=global`) to target the global layer, `harness=<name>`,
   and `memory=repo|external|ask`. Validate roles against
   `routing.sh --roles` and models/efforts against `routing.sh --models` —
   **never against a list you remember.** Invalid input → show what's wrong,
   write nothing. If valid, skip to step 5.

3. **Ask the SCOPE, then what to change.** Two AskUserQuestion rounds:
   - **Scope:** "this project only" (default) or "all projects (global default)".
     Global is right for "I always want X"; project for repo-specific needs.
   - **Items** (multiSelect): which roles, plus `gates`, `testing`,
     `implementation`, `review_panel`, `harness`, and `memory location`.
   If the user came with a natural-language request ("always use opus for review
   everywhere", "TDD off in this repo"), map it — including the scope — and
   confirm instead of re-asking.

4. **Per selected item, ask the new value.** One AskUserQuestion per role.
   **Get the model options from `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh --models`**,
   which prints what THIS harness accepts: tier names (`flagship`/`workhorse`/`fast`),
   family names, `inherit`, and the id patterns that let unreleased models
   through. Prefer recommending a **tier name** — it survives model releases
   without any edit. Effort options come from the same output; mark the current
   value. Then:
   - `harness`: any harness in the registry (`--models` header shows the active one).
   - `gates`: `pause_between_phases`, `auto_fix_review_findings` (true/false).
   - `testing`: `skip` ⊆ [ring-test, wield, proof, hone].
   - `implementation` — four keys, ask only about the ones selected:
     - `tdd` ∈ {ask, always, never} — whether forge dispatches the `jigsmith`
       (TDD, RED→GREEN evidence) or the plain `forger`; see `/smithy:jig`.
     - `tdd_level` ∈ {minimal, balanced, max} — how thorough the jigsmith's
       tests are. `minimal` = one test per requirement, primary behaviour plus
       the likeliest bug ("as long as the software works"); `balanced`
       (default) = + realistic edge and error paths; `max` = exhaustive,
       boundaries and adversarial cases included. This is a cost/confidence
       dial, not a quality switch — RED→GREEN ordering holds at every level.
     - `tdd_commits` ∈ {git, local} — `git` (default) commits each RED/GREEN/
       REFACTOR stage; `local` commits nothing and keeps a stage log instead.
       **When a user picks `local`, tell them the cost once:** commit ordering
       is the only TDD evidence the controller can verify independently, so
       `local` leaves the inspector reading the agent's own account. Then
       respect the choice — it's the right call for scratch worktrees, for
       histories the user wants clean, and when no commit grant exists.
     - `max_fix_cycles` — integer, default `2`: review→fix re-dispatches per
       task before escalating. Applies to the forger too, not just TDD. `0`
       means escalate on the first REJECTED.
   - `review_panel`: `auto | always | never` — whether the guild panel fires at
     end-of-forge (auto/always) or is skipped (never); it is the costliest
     smithy operation.
   - `memory location`: **global-only** — the default for NEW projects
     (`repo | external | ask`). To move THIS project's memory, see § Relocating.

5. **Probe model availability BEFORE writing.** Model access varies by account
   and changes over time (e.g. `fable` moved from subscription access to
   usage-credit access) — a config pointing at an unavailable model breaks every
   dispatch for that role. The registry deliberately accepts unknown ids so new
   releases need no plugin change; **this probe is the only thing that proves a
   value actually works.** For EACH model value being newly set (once per
   distinct model, `inherit` exempt):
   - Dispatch a minimal probe with `model` = the candidate and the prompt:
     "Effort: LOW. Reply with the single word: ok" — Agent tool under Claude
     Code; `spawn_agent`/`wait_agent`/`close_agent` under Codex (see
     `${CLAUDE_PLUGIN_ROOT}/references/harness.md`).
   - Probe returns → available; proceed.
   - Dispatch errors/rejects → do NOT write that role's change. Say which model
     failed and keep the current value; suggest the nearest available tier
     (flagship→workhorse→fast is the ordering; fable→opus→sonnet under claude,
     sol→terra→luna under codex).
   Never skip the probe on the assumption a model "should" be available — that
   is exactly the assumption this step exists to kill.

6. **Write only the changed keys**, one call per key:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh set global|project <dotted.key> <value>`
   It merge-writes (all other keys preserved, including unknown ones), parses
   JSON values (`false`, `5`, `["proof","hone"]`), and PRUNES a key whose value
   already equals the layer below — that is what keeps the files sparse. Report
   any `pruned` result as such; do not call it a write.

7. **Verify and echo.** Re-run `routing.sh --dump` and show the new effective
   table. Changed rows must now read `global` or `project` in the SOURCE column
   — matching the scope you wrote. If one doesn't, say so and investigate; do
   not claim success.

8. **Log.** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append calibrate <job-or-'-'> config <STATUS> config.json`
   with STATUS=DONE.

## Relocating this project's memory

Asked to move memory out of the repo (common when the repo cleans `docs/`):

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh --dump` — show where it is now.
2. Confirm the destination with the user. Then, since files must be MOVED and
   nothing here may do that silently, **ask before running it**:
   `mv <old> <new> && bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh set-mem <new>`
   For an empty/uninitialized dir, `init-memory.sh --external` (or
   `--at <dir> [--pointer]`) is enough on its own.
3. Re-export `$SMITHY_MEM` and re-run `paths.sh --dump` to prove the new path
   resolves. An in-repo `docs/smithy/` left behind still wins at rule 4 — remove
   it (with the user's approval) or the move has no effect.

## Rules

- Effort is prompt-level guidance (an injected banner per
  `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`), not an API parameter. If the
  user expects an API knob, tell them honestly.
- `inherit` means: omit the model parameter at dispatch; the agent's frontmatter
  default applies.
- Never edit `defaults/config.json` or `defaults/models.json` in the plugin.
  A user who needs a new model FAMILY (not just an id) adds it to
  `$SMITHY_HOME/models.json`, which merges over the plugin registry.
- Model values never need updating for a new release: tier names are stable, and
  unknown ids matching the harness's patterns pass through. If a user reports a
  new model being rejected, check `routing.sh --models` patterns before
  suggesting any code change.
