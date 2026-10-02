---
name: calibrate
description: "View or change smithy settings for ALL projects (global) or THIS project — model and effort per role, TDD settings, gates, review panel, where memory lives. Tests that a model works before saving it. Triggers: 'calibrate', 'smithy config', 'change the model for review'."
---

# Calibrate — Settings Editor

Settings come in three layers. For each key, the highest layer that sets it wins:

```
defaults  <plugin>/defaults/config.json   ships with smithy — NEVER edit
   ▲ overridden by
global    $SMITHY_HOME/config.json         every project on this machine (--global)
   ▲ overridden by
project   <memory>/config.json             this project only (the default scope)
```

Calibrate is the ONLY skill that writes the global and project layers. Both
stay SPARSE: they hold only what differs from the layer below.

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh calibrate auto` — read its summary.
   Exit 3 = memory has no home yet: this is the memory-location setup —
   ask the user and run the `init-memory.sh` line it prints (`${CLAUDE_PLUGIN_ROOT}/references/memory.md` § Location).
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`.
   Under Codex also `${CLAUDE_PLUGIN_ROOT}/references/harness.md`. Read `${CLAUDE_PLUGIN_ROOT}/references/memory.md`
   (§ Location, § Config layers) only for memory location or move work —
   not for model, effort or TDD changes.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| What to change | one-shot arguments, or the user's words | show the current table (step 1) and ask |
| Which scope | `--global` / `scope=global`, or clear from the words ("always", "everywhere" = global; "in this repo" = project) | ask: this project (default) or all projects |
| python3 (config.sh needs it) | continue | say so and stop — nothing can be written safely |

Nothing else must run first.

## Steps

1. **Show the current state** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh --dump`.
   Show the table: role, model, effort, source. SOURCE names the layer that
   gave the value (`defaults`, `global`, `project`), plus `(tier)` when a
   tier name was expanded and `(translated)` when a value from another
   harness was mapped by tier. The header shows the memory folder and how
   it was found.
   → verify: the table was shown.

2. **One-shot arguments** (if given) — `role=model/effort` pairs, e.g.
   `/smithy:calibrate review=sonnet/medium testing=haiku/low`, plus
   `--global` (or `scope=global`), `harness=<name>`, `memory=repo|external|ask`.
   Check roles against `routing.sh --roles` and models/efforts against
   `routing.sh --models` — **never against a list you remember**. Anything
   invalid → say what is wrong and write nothing. All valid → go to step 5.
   → verify: every value appears in the `--roles` / `--models` output.

3. **Ask scope, then items** — two AskUserQuestion rounds:
   - Scope: "this project only" (default) or "all projects". Global fits
     "I always want X"; project fits needs of this repo.
   - Items (multi-select): which roles, `gates`, `testing`,
     `implementation`, `review_panel`, `harness`, `memory location`.
   If the user came with a plain request ("always use opus for review",
   "TDD off in this repo"), map it — scope included — and confirm instead
   of asking again.
   → verify: scope and items are settled.

4. **Ask each new value** (one question per role). Model options come from
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh --models`: tier names
   (`flagship` / `workhorse` / `fast`), family names, `inherit`, and the id
   patterns that let new models through. Recommend a **tier name** — it
   survives model releases with no edit. Efforts come from the same output;
   mark the current value. Other items: see § Settings below.
   → verify: each chosen value is in the allowed set.

5. **Test each new model BEFORE saving.** Access differs per account and
   changes over time (e.g. `fable` moved from subscription access to
   usage-credit access). A role pointing at a model the account cannot use
   breaks every dispatch for that role. The registry accepts unknown ids on
   purpose, so this test is the only proof a value works. Once per distinct
   new model (`inherit` is exempt):
   - Dispatch a tiny agent with `model` = the candidate and the prompt
     "Effort: LOW. Reply with the single word: ok" (Agent tool on Claude
     Code; `spawn_agent` / `wait_agent` / `close_agent` on Codex).
   - It answers → available.
   - It errors → do NOT save that role. Name the failing model, keep the
     current value, suggest the next tier down (flagship → workhorse → fast;
     fable → opus → sonnet on Claude; sol → terra → luna on Codex).
   Never skip the test because a model "should" work.
   → verify: every new model answered "ok", or its role was left unchanged.

6. **Write only the changed keys**, one call each:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh set global|project <dotted.key> <value>`.
   It keeps all other keys (unknown ones too), reads JSON values (`false`,
   `5`, `["proof","hone"]`), and PRUNES a key that equals the layer below.
   Report a `pruned` result as pruned, not as a write. Memory location for
   new projects: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/config.sh memory-location repo|external|ask`.
   → verify: each call printed a write or a prune line.

7. **Check and show** — run `routing.sh --dump` again (or
   `config.sh source <key>` for non-routing keys). Changed rows must now show
   the scope you wrote (`global` or `project`). If one does not, say so and
   find out why; never claim success.
   → verify: the SOURCE of every changed key matches the scope.

8. **Log** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append calibrate <slug> config DONE config.json`.
   → verify: the ledger line exists.

## Settings

| Key | Values | What it does |
|---|---|---|
| `routing.<role>` | model + effort | which model and effort each role uses (steps 4–5) |
| `harness` | any harness in the registry (`--models` header shows the active one) | Claude Code or Codex model names |
| `gates.pause_between_phases` | true / false | the pipeline stops for a yes between phases |
| `gates.auto_fix_review_findings` | true / false | a standalone review may offer to fix Critical/High through `/smithy:strike` |
| `testing.skip` | subset of [ring-test, wield, proof, hone] | test suites temper skips |
| `review_panel` | auto · always · never | whether the guild panel runs after forge (auto/always) or is skipped (never). It is the costliest smithy step |
| `memory.location` | repo · external · ask | **global only** — where NEW projects keep memory. To move THIS project's memory, see § Moving memory |

### TDD settings (they must match `/smithy:jig` § The three settings — jig is the source)

| Key | Values | What it does |
|---|---|---|
| `implementation.tdd` | ask (default) · always · never | whether forge uses the `jigsmith` (test-first) or the plain `forger` |
| `implementation.tdd_level` | minimal · balanced (default) · max | how many tests. `minimal` = one test per requirement: the main behavior plus the likeliest bug. `balanced` = plus realistic edge and error paths. `max` = boundaries, hostile input, one requirement at a time. Tests-first order holds at every level |
| `implementation.tdd_commits` | clean (default) · stages | `clean` = ONE commit per task (tests and code together); the tests-first order is proven by `${CLAUDE_PLUGIN_ROOT}/scripts/tdd-snap.sh` pictures. `stages` = a commit per stage (`test:`, `feat:`, `refactor:`) |
| `implementation.max_fix_cycles` | number, default 2 | fix rounds after the job's one final review before smithy stops and asks the user. Applies to every builder, not only TDD. `0` = never fix on its own; go straight to the user |

**Old names:** `tdd_commits` = `git` is read as `stages`, `local` as `clean`
(`config.sh get` prints a NOTE). If you see an old name in a layer, tell the
user what it means and offer to save the new name. Always write new names.

## Moving memory

Asked to move memory out of the repo (common when the repo cleans `docs/`):

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh --dump` — show where it is now.
2. Confirm the destination with the user. Files must be MOVED, which never
   happens silently — **ask before running**:
   `mv <old> <new> && bash ${CLAUDE_PLUGIN_ROOT}/scripts/paths.sh set-mem <new>`.
   For an empty or new folder, `init-memory.sh --external` (or
   `--at <dir> [--pointer]`) is enough on its own.
3. Run `paths.sh --dump` again to prove the new path resolves. After
   `set-mem`, an in-repo memory folder left behind is IGNORED: the registry
   (rule 3 in `${CLAUDE_PLUGIN_ROOT}/references/memory.md` § Location) beats an existing in-repo
   folder (rule 4). Tell the user they may keep or delete it; never delete
   it yourself.

## Rules

- **Effort is not an API setting.** It is a banner put at the top of the
  agent's prompt (text in `${CLAUDE_PLUGIN_ROOT}/defaults/models.json` → `effort_banners`). Say so
  if the user expects an API knob. On Claude Code the `route-guard.sh` hook
  stamps the routed model and banner onto every smithy dispatch, so what you
  save is what runs (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/route-guard.sh table`
  shows the enforced map). Off Claude Code no hooks run and routing is advice
  only (`${CLAUDE_PLUGIN_ROOT}/references/harness.md`) — say so if asked whether it is binding.
- `inherit` = leave the model parameter out at dispatch; the agent file's
  default applies.
- Never edit `${CLAUDE_PLUGIN_ROOT}/defaults/config.json` or `${CLAUDE_PLUGIN_ROOT}/defaults/models.json`. A new model
  FAMILY (not just an id) goes in `$SMITHY_HOME/models.json`, which merges
  over the plugin's list.
- New model releases need no edit: tier names are stable and unknown ids
  that match the harness's patterns pass. If a new model is rejected, check
  the `routing.sh --models` patterns before suggesting any code change.

## Done when

- [ ] the current table was shown before any change
- [ ] every new model passed the "ok" test, or its role was left unchanged (say which)
- [ ] only changed keys were written, to the scope the user chose; prunes reported as prunes
- [ ] the after-table (or `config.sh source`) shows each changed key from that scope
- [ ] any old `tdd_commits` name found was explained to the user
- [ ] ledger line written

## Output

The changed config layer: `$SMITHY_HOME/config.json` (global) or `<memory>/config.json` (project).

`Next: none — run /smithy:calibrate again any time to see the table`
