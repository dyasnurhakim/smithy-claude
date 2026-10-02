# Changelog

## 0.14.1 — unreleased

Routing is now enforced for smithy agents in every project.

```
before: smithy:* dispatch ─▶ route-guard ─┬─ memory folder?  yes → corrected
                                          └─ no  → NOT corrected (silent no-op)
after:  smithy:* dispatch ─▶ route-guard ─▶ corrected in any project
```

- **The gap.** `route_guard.py` skipped every dispatch in a project with no
  smithy memory folder. So when a session that had not run a smithy skill yet
  dispatched `smithy:forger` (or any smithy agent), model and effort were not
  enforced. Installs older than 0.13 had no route-guard at all.
- **The fix.** A `smithy:*` dispatch is routed everywhere — dispatching a
  smithy agent IS using smithy. With no project config, routing comes from the
  defaults + the global layer (`$SMITHY_HOME/config.json`). Works outside a git
  repo too. Still fails open on any error.
- **Kept narrow on purpose.** A BARE agent name (`inspector`, `forger`) is
  still routed only in smithy-managed projects: elsewhere it may be the
  project's own agent that shares the name. `guard.sh` and `mcp-guard.sh` stay
  managed-projects-only (they guard the project, not smithy's own agents).
- Tests: `route-guard-matrix.sh` — the old "no-op without a memory folder" case
  is replaced by three: `smithy:*` routed, bare name left alone, other agents
  left alone.

## 0.14.0 — unreleased

Cheaper TDD with a clean history, skills that work on their own, read-only
lookup tools for agents, and plain English everywhere.

```
before (per task, per requirement)            after (per task)
test → commit → code → commit → refactor      tests (all) → code → ONE commit
  → commit, ×N requirements                   proof: tdd-snap pictures, no extra commits
inspector review after EVERY task             self-check per task, ONE review per job
```

### TDD: one clean commit per task
- **`scripts/tdd-snap.sh`** proves "tests came first" without commits. Each
  stage saves a *picture* of the working folder as a git tree object (a
  throw-away index + `write-tree`): no commit, no ref, HEAD and the index are
  never touched. `verify` checks the order (RED adds a test, GREEN adds code,
  nothing changed after the last picture) and writes its verdict into the log;
  `verify --audit` re-checks only the order at the end of a job.
- **`tdd_commits` is now `clean` (default) | `stages`.** `clean` = one commit
  per task, tests and code together. Old values still work and print a note:
  `git` → `stages`, `local` → `clean`. `local` is gone because `clean` does
  what it did *and* has proof the controller can check itself.
- **Fewer test runs.** At `minimal`/`balanced` the agent writes all of a
  task's tests, runs them once (RED), writes the code, runs once (GREEN), then
  the full suite once. One-requirement-at-a-time stays for `max`.
- **One home for the TDD rules:** `skills/jig/SKILL.md`. dispatch, forge and
  calibrate point to it instead of repeating it.
- Measured on the same 4-requirement task (sonnet, medium effort): 9 commits →
  1; 12 → 9 tool calls; 52 s → 35 s; 56.8k → 51.9k agent tokens. The bigger
  saving is on the controller side (next section), which this test did not
  measure.

### Review: a self-check per task, one review per job
- forger and jigsmith end every task with a five-item self-check in their
  report. The main session then dispatches ONE inspector over the whole job
  (`BASE..HEAD`), judges the findings, and runs fix rounds
  (`implementation.max_fix_cycles`), re-reviewing only the fix diff.
- **Bug fixed:** `local` mode reviewed an empty diff — nothing was committed
  but the package diffed `BASE..HEAD`.
- **Bug fixed:** forge and jig ran `record-base` before every task, so a
  "whole job" review only saw the last task; strike, anneal and inspect also
  overwrote the active job's base. The job base is now set once. Standalone
  work passes `--base <start sha>` instead.
- `review-package.sh build` takes `--base <ref>` (never writes STATE.md) and
  `WORKTREE` as a target (includes uncommitted changes).

### Every skill works on its own
- **`scripts/start.sh <skill> [auto|new|<slug>]`** is step 1 of every skill:
  finds or creates the memory folder (exit 3 = ask the user where), reads
  STATE.md, picks the job slug, logs STARTED. Twelve skills used to skip this
  and could not start cleanly without the pipeline.
- Missing inputs now have fallbacks instead of dead ends: blueprint without a
  spec asks ≤5 questions and writes a mini spec; forge and jig without a plan
  write one brief and confirm it; inspect and guild take `--base`.
- Fixes from reviews and QA go to `/smithy:strike` (no plan needed) instead of
  forge, which refused to run without one.
- **One layout for every SKILL.md** (`references/skill-shape.md`): Start,
  Needs (with what to do when something is missing), Steps (each with
  `→ verify:`), Done when, Output with one `Next:` line.
- **`references/memory-card.md`** (≈50 lines) replaces reading the full
  `memory.md` in everyday skills.
- Drift fixed: fix budgets always come from `max_fix_cycles`; ledger phase =
  the skill's own name; one finding fingerprint (`envelope.md`); personas
  named by file path; models named by routing role; bug fixes always
  test-first (strike now sends bug items to the jigsmith).

### Lookup tools for agents, with a guard
- All five agents may use **read-only MCP tools**. Agents now use a
  `disallowedTools` deny-list instead of a `tools:` allow-list: a live test
  showed an `mcp__*` wildcard in `tools:` grants nothing in Claude Code
  2.1.x, so an allow-list cut agents off from MCP. Every agent loses Agent,
  Skill, cron and the like; inspector and annealer also lose Write and Edit.
  Lookups available:
  memory (claude-mem), code graph (understand-anything, graphify, …), docs
  (context7, …). None are required; without them agents use Read/Grep.
- **`scripts/mcp-guard.sh`** — a PreToolUse hook on `mcp__.*`: a tool whose
  name says it sends, creates, updates or deletes (or says nothing known)
  makes Claude Code **ask** the user first, even when the user's own rules
  name the tool. Read tools get no decision, so normal permissions apply. It
  never says "allow". Smithy-managed projects only, like `guard.sh`.
- Creed §10 sets the budget (1 search, 1 timeline, 3 records) and the trust
  order (code and `git log` > ledger > lookup results).

### Plain English everywhere
- Creed §8 **Finish the job**: a skill ends only when every Done-when item is
  checked against real evidence; anything left is listed, never hidden.
- Creed §9 **Voice**: simple English, short but complete, a picture (ASCII
  flow, table, before/after) where it helps — for chat, specs, plans,
  reports, code comments and script messages.
- Every skill, agent, reference, persona, playbook, command alias and script
  comment/message was rewritten to match. Script behavior is unchanged.

### Fixed during the release review
Four parallel reviewers (script bugs, prompt-vs-script interfaces, lost
rules, cold standalone runs) found these; all are fixed and most have a test:
- `mcp-guard` read a `tool_name` key hidden inside `tool_input` — it now
  parses the JSON for real (unreadable → ask). A bare `query` / anything with
  `sql` and `resolve_*` tools now ask (they can write); snapshots read.
- Lanes: `record-base`/`build` used the project STATE.md while `start.sh` read
  the lane's — two jobs could overwrite each other's base. Both now use the
  current state folder (lane falls back to the project base).
- The single final review never saw the implementers' reports (it pointed at
  `forge-report.md` before it existed). The package now takes a reports folder.
- `review-package … WORKTREE` missed untracked files; a misplaced `--base` was
  silently ignored (now refused).
- `tdd-snap`: a second GREEN after a full-suite fix failed verify (now allowed,
  with a warning); multi-line notes broke the log; non-ASCII paths were
  misread; deleting a test counted as RED; `..` in a name escaped the memory
  folder; a symlinked memory folder leaked into pictures. Parallel tasks run
  `verify` inside their own worktree.
- `start.sh`: two runs at the same moment could get the same slug (now an
  atomic `mkdir`); skill names and STATE's active job are validated.
- Prompts: forge's one-task mode now writes a short plan.md for the review;
  temper's envelope uses a valid kind; wield/hone keep the previous run as
  `.prev` before writing, so trends work; skills that need a running app share
  one "Run line" in decisions.md; restored creed §2 "verbatim" and the full §6
  destructive list; the finding fingerprint keeps wield's pre-0.14 formula so
  old trend files still match.

### Found by live tests (`claude -p --plugin-dir`, installed copy disabled)
- Agents could not reach MCP at all: an `mcp__*` wildcard in `tools:` grants
  nothing in Claude Code 2.1.x → agents use a `disallowedTools` deny-list.
  Checked live: the read-only annealer loads claude-mem via ToolSearch,
  searches, and has no Write/Edit; the main session's MCP write was stopped
  by mcp-guard.
- Plugin paths in prompts had no `${CLAUDE_PLUGIN_ROOT}/` prefix, so the model
  first looked for `references/creed.md` inside the skill folder (3 failed
  reads per skill run). All 191 plugin paths in prompt files now carry it.
- A false RED slipped through: a "throws TypeError" test passed before the
  code existed (calling undefined also throws TypeError). The RED note is now
  `<n> of <m> failing` and jig requires n = m.
- End-to-end `/smithy:jig` on a toy repo after the fixes: one commit
  (`feat: add slugify`), `7 of 7 failing` at RED, `tdd-verify: OK`, one
  review APPROVED, 0 failed tool calls, $0.93 for the whole skill run.

### Tests
- New: `tdd-snap-matrix.sh`, `mcp-guard-matrix.sh` (real tool names from
  common servers), `review-package-matrix.sh`, `start-matrix.sh`,
  `skill-lint.sh` (layout, size, every referenced file exists, drift checks,
  manifest versions agree).
- Fixed: `worktree-matrix.sh` pointed at an old checkout path and had been
  failing since 0.6.0.

## 0.13.0 — unreleased

Model routing stops being a suggestion. A second PreToolUse hook forces every
smithy subagent dispatch to the configured model and effort.

- **The bug.** `references/dispatch.md` §1 told the controller to pass the
  routed model and prepend the routed effort banner — and that was the entire
  mechanism. Nothing verified it, so all three drift modes ran unchecked: the
  `model` parameter omitted (the subagent then silently inherits the session
  model), a cheaper tier picked by intuition, or the effort banner missing or
  carrying the wrong level. A subagent has no way to know what it was supposed
  to run as, so nothing downstream noticed either. `guard.sh` had made git
  safety deterministic for exactly this reason; routing never got the same
  treatment.
- **`scripts/route-guard.sh` + `scripts/lib/route_guard.py`** — a PreToolUse
  hook on subagent dispatch that REWRITES the call to match config instead of
  rejecting it (correcting costs nothing; denying costs a turn to reach the
  same place). It injects/corrects `model`, strips any wrong or stale effort
  banner and prepends the right one, and announces every correction in-context
  as `[smithy-route-guard] …` — silent rewriting would be worse than the bug.
- **Role comes from the agent**, per dispatch.md's table: `forger`/`jigsmith`
  → implementation, `inspector` → review, `annealer` → debugging, `temperer` →
  testing. A brief may pin a different role with a `smithy-role: <role>` line —
  the only sanctioned override, and it selects a ROLE, never a raw model.
- **Fails open, deliberately** — the inverse of `guard.sh`. That guard blocks
  on doubt because the risk is a destroyed repo; here the risk is a
  slightly-wrong model, and a dead dispatch is worse than an unrouted one. A
  malformed payload, a missing `python3`, an unreadable config: dispatch
  proceeds untouched. For the same asymmetry it skips `SMITHY_PATHS_FAST` —
  it runs once per dispatch, not before every Bash call, so it can afford full
  path resolution and doesn't inherit the fast path's blind spot for projects
  using the external-memory default.
- **Two cases it reports instead of fixing**, both meaning "this config can't
  dispatch here": a routed model the harness won't accept as a dispatch value
  (a raw `id_patterns` passthrough like `claude-opus-9-9`), and a config whose
  `harness` isn't the one running — plugin hooks only run under Claude Code, so
  a `codex` config would inject `sol` and fail the harness's `updatedInput`
  schema validation, taking the banner fix down with it. The banner is still
  enforced in both cases.
- **Effort-banner text is now registry DATA** — `defaults/models.json` →
  `effort_banners`, next to `efforts`, so it inherits the
  `$SMITHY_HOME/models.json` deep-merge and can be retuned per machine without
  touching a script. `smithy_config.py banners` reads it; dispatch.md §1's
  table is explicitly labelled a reading copy.
- Emits no `permissionDecision` — "allow" would short-circuit the user's own
  permission rules for subagent dispatch, and this hook's job is routing, not
  authorization. Untouched: non-smithy agents, other plugins' same-named
  agents, and every project without smithy memory.
- `route-guard.sh table` prints the enforced agent → role → model/effort map.
  Docs updated: dispatch.md §1 (hook-enforced, not advisory), harness.md (both
  deterministic layers degrade under Codex, not just the git guard), calibrate
  (what's binding and where), README, CLAUDE.md, SessionStart digest rule 3.
- `tests/route-guard-matrix.sh` — 42 cases. Suite total: 283.

## 0.12.0 — unreleased

Parallel work gets isolated state that merges back; three new TDD dials;
an `xhigh` effort level.

- **State lanes — parallel pipelines without a shared-state collision.**
  `$SMITHY_MEM` is deliberately one dir per project anchored on the main
  worktree, which meant concurrent units of work appended to the same
  `ledger.md` and overwrote the same single-`Active job` `STATE.md`. New
  `scripts/lane.sh` namespaces exactly the mutable files
  (`STATE.md`/`ledger.md`/`decisions.md`) under `$SMITHY_MEM/lanes/<name>/`;
  everything else (config, `jobs/`, personas, guard tokens) stays
  project-wide — a lane is a unit of work, not a different set of
  preferences, and must never be able to mint itself a commit grant.
  Commands: `start`/`list`/`current`/`status`/`merge`/`merge-all`/`abandon`.
- **Lanes resolve automatically inside a worktree.** `paths.sh` gained lane
  resolution (`$SMITHY_LANE` env → `<worktree>/.smithy-lane` marker → none),
  pure bash so the PreToolUse guard hook keeps its no-interpreter budget, and
  exports `SMITHY_STATE_DIR`. `worktree.sh create` now opens a lane named
  `<job>-<task>` and drops the marker, so a dispatched agent lands in the
  right lane knowing nothing about lanes. Unsafe names (`../escape`, `a/b`,
  leading dot) are IGNORED rather than sanitised — writing state somewhere
  the caller did not ask for is worse than writing it to the shared root.
- **Reads merge, writes don't.** Inside a lane `ledger.sh tail`/`last` return
  the lane's events merged over the project's in timestamp order, so a
  controller resuming after compaction sees the whole history and reaches the
  same resume decision it would have reached serially. `ledger.sh where`
  reports which file is being appended to.
- **Merging is a timestamp-stable union, not a three-way merge.** The ledger
  is append-only with a leading ISO timestamp, so `lane.sh merge` sorts —
  no conflicts, no lost events, each lane's internal order preserved within a
  tied minute. It also appends the lane's `decisions.md`, refreshes the
  project `STATE.md`'s `Last event` line, and archives the lane under
  `lanes/.merged/`. It deliberately does NOT rewrite `Phase`/`Next step` —
  those are semantic and belong to the controller. `abandon` archives a
  rolled-back lane whose events must never enter the ledger. A `mkdir`-based
  lock keeps two concurrent merges from interleaving.
- **`worktree.sh` no longer leaks its markers into commits.** `.smithy-worktree`
  (and the new `.smithy-lane`) are now added to the git common dir's
  `info/exclude`, so an agent's `git add -A` cannot sweep them into a task
  branch and `absorb` cannot merge that scratch onto the working branch —
  a pre-existing bug that also broke forge's clean-tree precondition inside
  worktrees. `remove` reports an unmerged lane rather than merging it: a
  removed checkout is disposable, an event log is not.
- **`implementation.tdd_level`** ∈ `minimal | balanced | max` (default
  `balanced`) — how thorough the jigsmith's tests are. `minimal` is one test
  per requirement (primary behaviour + the likeliest bug: "as long as the
  software works"), `max` is exhaustive including adversarial cases. It cuts
  test COUNT, never the RED→GREEN ordering.
- **`implementation.tdd_commits`** ∈ `git | local` (default `git`) — `local`
  commits nothing and keeps a stage log at
  `reports/raw/task-N-tdd-stages.md` instead, for scratch worktrees, clean
  histories, or when no commit grant exists. forge skips the commit-grant
  precondition in that mode, and the inspector verifies ordering from the
  stage log + diff rather than `git log`. Documented honestly: commit
  ordering is the only TDD evidence the controller can verify independently,
  so `local` trades that away.
- **`implementation.max_fix_cycles`** (default `2`) replaces the hardcoded
  "max 2 fix cycles per task" in forge/jig/dispatch. Applies to the plain
  forger as well as the jigsmith; `0` means escalate on the first REJECTED.
- **`xhigh` effort**, between `high` and `max` — the ladder is now
  `low | medium | high | xhigh | max` with its own dispatch banner. Because
  efforts are registry data read through `routing.sh --models`, calibrate
  picks the new level up with no skill change.
- New `tests/lane-matrix.sh` (50 assertions: resolution, unsafe-name refusal,
  isolation, merge union, abandon, worktree wiring, marker exclusion). All
  five suites green.

## 0.11.0 — unreleased

Memory can live outside the repo; two-tier (global + project) config; a
model registry that survives future releases without a plugin update.

- **Memory is no longer pinned to `<repo>/docs/smithy/`.** New
  `scripts/paths.sh` is the single resolver — every script sources it
  instead of re-deriving the repo root. Resolution, first match wins:
  `$SMITHY_MEM_DIR` env → `<repo>/.smithy-path` pointer file →
  `$SMITHY_HOME/projects.tsv` registry (fully outside the repo) → an
  existing `<repo>/docs/smithy/` (back-compat) → the global
  `memory.location` default. Fixes the case where a project cleans,
  regenerates, or gitignores `docs/` and destroys the ledger mid-job.
  `paths.sh --dump` shows the resolved dir and which rule produced it.
- **`init-memory.sh` asks instead of guessing.** With no location
  configured it exits 3 and names the options (`--in-repo`, `--external`,
  `--at <dir>`, plus `--pointer` and `--global-default`) rather than
  silently creating `docs/smithy/`. Existing projects are untouched:
  a `docs/smithy/` that already exists still wins.
- **Two config layers above the defaults**: `$SMITHY_HOME/config.json`
  (global — every project on this machine) and `$SMITHY_MEM/config.json`
  (project). Merge is per key, so a global model and a project effort
  combine on one role. `--dump`'s SOURCE column names the winning layer.
  New `scripts/config.sh` (`get`/`source`/`set global|project`/`layers`/
  `show`/`memory-location`) is the layered read/write surface; writes are
  sparse — setting a value the layer below already provides prunes the key.
- **Model registry is now DATA, not shell.** `defaults/models.json`
  replaces the hardcoded `CLAUDE_MODELS`/`CODEX_MODELS` lists. Three ways
  a new release needs no smithy edit: (1) tier names
  `flagship`/`workhorse`/`fast` are valid config values and never change —
  the shipped defaults use them; (2) `id_patterns` pass unknown ids through
  verbatim, so `claude-opus-6`, `sonnet-9`, `gpt-7` work today; (3)
  `$SMITHY_HOME/models.json` deep-merges over the registry, so a whole new
  harness family can be added locally. Cross-family values translate BY
  TIER. The registry validates syntax only — calibrate's dispatch probe
  remains the availability gate.
- **`/smithy:calibrate` gained scope.** Asks global vs project before
  writing, sources its model/effort/role options from `routing.sh
  --models`/`--roles` instead of a hardcoded prose list, and documents
  relocating an existing project's memory.
- **Fixed: the ledger split across parallel worktrees.** `ledger.sh` used
  `--show-toplevel` (worktree-local) while `guard.sh` used
  `--git-common-dir` (main worktree), so during a parallel forge batch each
  linked worktree wrote its own ledger while grants read from the main one.
  All memory now anchors on the main worktree.
- **Routing got ~28x fewer subprocesses.** `--dump` spawned python3 once
  per role/field/config-file (28 spawns, 42 with a third layer); JSON work
  is now one `scripts/lib/smithy_config.py` call. Guard's hook path stays
  pure bash (rules 1-4, no interpreter spawn): +5ms per Bash call.
- New surfaces: `routing.sh --models`, `routing.sh --roles`,
  `paths.sh set-mem|unset-mem`, `config.sh memory-location`.
- Skill prose now uses `$SMITHY_MEM/...` throughout (73 call sites) with a
  bootstrap that resolves it per session. `references/memory.md` gained a
  Location section; `references/harness.md` documents tier resolution.
- New test suite `tests/paths-matrix.sh` (all five resolution rules,
  external-memory guard/ledger/review-package behavior, two-tier writes,
  worktree sharing). `tests/routing-matrix.sh` extended to 3 layers, tier
  expansion, unreleased ids, and user-extended registries.

## 0.10.0 — unreleased

Codex CLI harness support (GPT-5.6 sol/terra/luna + older generations).

- **Harness-aware model routing**: `"harness": "claude" | "codex"` in
  config; routing.sh translates tiers both ways (fable/opus↔sol,
  sonnet↔terra, haiku↔luna) so one config works on both harnesses;
  explicit older ids (gpt-5.5, gpt-5.4, gpt-5.5-codex, …) pass through
  under codex and fall back to the role default under claude;
  --dump shows the harness and marks translations
- **references/harness.md**: dispatch mapping (Agent tool ↔
  spawn_agent/wait_agent/close_agent with multi_agent=true), per-dispatch
  model caveats, sandbox/detached-HEAD detection, and the honest
  degradation list — hooks don't run under Codex, so the git/destructive
  guard is prompt-level there (creed §6 + manual `guard.sh check`)
- **CLAUDE.md + AGENTS.md symlink** (harness entrypoint) and
  **.codex-plugin/plugin.json** (interface manifest mirroring the proven
  superpowers adapter shape)
- calibrate: harness item; probe adapted per harness; model options per
  family; using-smithy rule 8
- tests/routing-matrix.sh: 15 cases (translation both ways, gpt-*
  passthrough, harness fallback, invalid rejection)
- **Marketplace packaging**: scripts/sync-to-codex-plugin.sh stages the
  canonical Codex plugin tree (skills + agents + references + defaults +
  functional scripts; drops hooks/commands/tests/repo ceremony) with
  --stage-only for local inspection, or clones your fork of openai/plugins,
  syncs plugins/smithy/, and opens the submission PR; README documents both
  install paths (/plugins marketplace once listed; AGENTS.md clone today)
- Flag: the Codex port is structurally faithful but not yet live-tested
  under a Codex session

## 0.9.0 — unreleased

- **Personas for every subagent** (`references/persona-modes.md`): four
  consumption modes — judgment lens (inspector, unchanged/contextual),
  build constraints (forger/jigsmith: masters/engineer.md default on every
  task + at most one domain specialist by task type), test lens (temperer:
  qa on ring-test, end-user/support + project personas on wield, sre on
  proof, none on hone), investigation lens (annealer: engineer default,
  security/sre/end-user by symptom). Output contracts unchanged — the
  persona shapes the work, not the envelope. Blueprint tags briefs;
  anneal picks by symptom; strike inherits; temperer never gets
  engineer.md (its edge-case duty already lives in playbooks + qa.md).

## 0.8.0 — unreleased

- **`strike` skill (alias `/smithy:fix`)** — one-shot fix lane for small
  KNOWN changes (≤5 items, no spec): lightweight inline plan → ONE
  confirmation gate (doubles as the commit grant) → plain forger per item
  with TDD explicitly overridden → targeted tests (verify commands +
  covering suites, revert on persistent failure) → one whole-diff inspect →
  single strike-report.md. A thin profile over the forge machinery: same
  dispatch protocol, forger agent, guard, and envelope — skips the ceremony
  (spec, decomposition, persona pass, per-task review), never the subagent
  rules. Unknown-cause items route to anneal; >5 items route to blueprint.

## 0.7.0 — unreleased

Token efficiency (typical pipeline run ~30–45% lighter; every session ~2k
tokens lighter) + deeper plan review.

- SessionStart hook injects a ~10-line digest (routing one-liner + 5 iron
  rules) instead of the full using-smithy skill (~115 lines); full router
  loads on demand
- Read-once rule (creed §7 + digest): reference files read once per
  session, re-read only post-compaction
- All 19 skill descriptions trimmed ~60% (aliases untouched); YAML-quoted
- Review packages: diff context -U10 → -U5 (config `review_diff_context`),
  implementor report referenced by PATH instead of embedded
- Guild packages scoped per persona family: full (engineer/security/qa/
  product), UI slice (uiux/designer/end-user/marketing), infra slice
  (sre/support) — every slice keeps the plan + complete file list
- Verbatim evidence blocks capped at ~25 lines (agents + creed); overflow
  goes to reports/raw/ by path
- Brief envelopes travel light: artifacts/next_action optional for
  kind: brief (validator updated)
- Blueprint persona pass DEEPENED, not trimmed: structured per-persona ×
  per-task assessment table inline, plus an optional dispatched deep pass
  (1–3 persona overlays reviewing the PLAN itself in isolated contexts,
  offered for auth/payments/migration/public-UI jobs)

## 0.6.1 — unreleased

- **One report per forge run, not per task**: per-task files
  (task-N-impl/review/pkg.md) are now explicitly TRANSIENT scratch — still
  written during the loop (review packages and machine-read statuses need
  them) but consolidated into a single `reports/forge-report.md`
  (envelope kind: forge-report; per-task summary table, carried concerns)
  and deleted at forge exit. Standalone single-task runs write the
  consolidated report directly.

## 0.6.0 — unreleased

Parallel execution, worktree isolation, technical aliases.

- **Blueprint parallel batches**: tasks marked `∥ batch-X` only with proven
  disjointness (file-set evidence in the plan; no cross-imports/shared
  scaffolding; ≤4 per batch; default sequential)
- **Forge parallel execution — user-gated, integration-staged**: a batch
  marker is an offer, not an order — forge asks parallel vs sequential per
  batch. Parallel: one git worktree + branch per task via
  scripts/worktree.sh, single-message dispatch, per-branch review BEFORE
  absorb; absorbs land on an INTEGRATION branch (worktree.sh integrate)
  where the batch's verify commands + test suite run before
  `worktree.sh land` merges into the working branch; conflict = mis-marked
  batch → clean abort + escalate; all branches LOCAL unless the user asks
  to push; smithy-created worktrees ALWAYS removed at batch end
  (marker-authorized); user-created worktrees never auto-removed — asks
  auto-clear vs leave
- **Blueprint persona pass**: 2–4 job-relevant personas (+ project
  personas) applied to the PLAN inline before it hardens — missing tasks,
  untestable requirements, risks worth their own task; recommendations
  accepted/rejected at the plan gate
- **Companion-tool honoring** (using-smithy rule 7 + creed §0): tools named
  in the user's CLAUDE.md/rules (claude-mem, graphify, understand-anything,
  context7, …) are used where they fit the phase, per the user's own
  routing; tools not in the user's configuration are never assumed
- **guard.sh worktree-aware**: grants/tokens resolve to the MAIN worktree
  via git-common-dir, so parallel task commits honor the plan-gate grant
- **review-package.sh** gains a ref argument (review a task branch before
  merging it)
- **18 technical aliases** as command shims (/smithy:plan → blueprint,
  /smithy:qa → wield, /smithy:tdd → jig, /smithy:debug → anneal, …) —
  full table in README and using-smithy
- tests/worktree-matrix.sh: 16-case lifecycle matrix (create/absorb/remove/
  clean, guard-in-worktree, user-worktree refusal, conflict abort)

## 0.5.0 — unreleased

Proof-carrying reviews.

- **Inspector evidence contract** (binding, all reviews): every finding
  needs file evidence (file:line + excerpt), command evidence (verbatim
  output), or screenshot evidence; plus "why flagged" and "severity —
  because" rationale tied to the persona's calibration. No proof → reported
  as cannot-verify (confidence ≤4), not as a finding. New "Finding details"
  block per finding in the report template.
- **Guild live-evidence stage**: for user-facing diffs with a runnable
  target, UI-facing personas (master-uiux, patron-end-user/marketing/
  support) drive the app headlessly via Playwright and save screenshots to
  docs/smithy/jobs/<slug>/reports/guild-evidence/<persona>/ — the
  screenshot is the proof. Local targets only; no target → UI findings
  capped at cannot-verify.
- **guild-verdict.json**: machine-readable twin of the markdown verdict
  (findings with fingerprint, personas, tag, severity + severity_reason,
  confidence, location, evidence object, fix, status) for CI and trends.
- **Design skills**: `pattern` (design creation — subject-grounded style
  directions with self-contained HTML previews as the proposal, token
  system, states, motion, copy-as-design voice → docs/smithy/DESIGN.md)
  and `burnish` (design review & improvement — baseline screenshots at
  3 breakpoints, findings judged against DESIGN.md or declared heuristics
  with screenshot proof, gated surgical fix loop with before/after pairs
  and revert-on-regression, md+json report)
- **master-designer persona** (10th persona): identity & distinctiveness
  judge — the default test (incl. the three current AI-design clichés),
  signature-element discipline, subject grounding, copy-as-design; fires
  in guild on UI diffs alongside master-uiux (function vs design);
  DESIGN.md is its binding standard when present
- **wield screenshots now mandatory** (fixes: browser QA ran without
  capturing anything): evidence dir `reports/qa-evidence/` in every UI
  brief; one screenshot per flow assertion, before/after pairs around
  mutations, one per finding; temperer agent gained the same binding
  evidence contract; the controller rejects UI QA reports with zero PNGs
  (`ls <evidence-dir>` verbatim in the report). Plus `test-qa.json` —
  machine-readable QA twin with health scores, same findings shape as the
  guild JSON.

## 0.4.2 — unreleased

- `fable` (Claude 5, Mythos-class — above opus) added to the model routing
  vocabulary: routing.sh enum, calibrate options, dispatch tier table,
  README. Verified live with a real fable dispatch.
- calibrate now PROBES model availability before writing any model change
  (minimal test dispatch per candidate model) — model access varies by
  account and shifts over time (e.g. fable subscription → usage-credit);
  a failed probe keeps the current value and suggests the nearest tier.
  dispatch.md documents the runtime fall-back rule for rejected dispatches.

## 0.4.1 — unreleased

Guard rails expanded from git-only to full destructive-operation coverage.

- New blocked categories (all with the one-shot `allow-once` escape after a
  live user yes): cloud deletion/termination (aws terminate-instances /
  delete-* / s3 rb|rm, gcloud delete, gsutil rm|rb, az delete, fly/heroku/
  vercel destroy), IaC (terraform/pulumi/cdk destroy), containers
  (docker rm/rmi/prune/volume rm/compose down, kubectl delete/drain, helm
  uninstall), databases (DROP/TRUNCATE/ALTER-DROP via any client, DELETE
  FROM without WHERE, dropdb, mysqladmin drop, redis FLUSHALL/FLUSHDB,
  mongo dropDatabase, prisma/rails/artisan/Django/alembic migration
  resets, npm unpublish), filesystem (find -delete, rsync --delete, shred,
  dd of=/dev/*, mkfs, truncate -s 0)
- `guard.sh allow-once`: one-shot destructive override, consumed by exactly
  one command, never unlocks push; `status` shows it; `revoke` clears it
- SQL rules require a database-client context (no false positives on
  "drop table" in commit messages); DELETE FROM with a WHERE clause passes
- `tests/guard-matrix.sh`: self-contained 57-case regression matrix

## 0.4.0 — unreleased

Personas, git guard rails, inter-agent envelope.

- **Persona system**: 5 guild masters (engineer, security, qa, uiux, sre —
  craft) + 4 patrons (end-user, product, marketing, support — experience)
  as overlay files on the shared inspector agent
- **`guild` skill**: production-readiness panel — roster selected by diff
  content, personas dispatched in parallel, findings deduped/cross-verified,
  one PRODUCTION_READY | NOT_READY verdict (craft AND experience must be
  clean); wired between FORGE and TEMPER, `review_panel: auto|always|never`
- **`commission` skill**: generates project-level test personas from real
  user roles (evidence from spec/README/auth code + user interview);
  wield gains persona mode (per-persona QA flows + cross-persona permission
  checks — a CANNOT that succeeds is Critical)
- **Git guard rails**: PreToolUse hook + `scripts/guard.sh` — push needs a
  per-push live user yes (one-shot token), commits need the job's plan-gate
  grant (auto-revoked at job end/handover), history rewrites and out-of-tree
  `rm -rf` always blocked; enforcement only in smithy-managed projects;
  creed §0: user CLAUDE.md rules override smithy protocol
- **Inter-agent envelope**: YAML envelope on every brief/report/verdict
  (kind/job/unit/status/confidence/key_facts/concerns/next_action) +
  `scripts/envelope.sh`; controllers copy unresolved key_facts forward —
  key information survives hops

## 0.3.0 — unreleased

Multi-language stack support.

- Stack detection extended: Go (go.mod), Java/JVM (pom.xml,
  build.gradle[.kts] — Maven and Gradle wrappers), Rust (Cargo.toml)
- 12 new per-stack playbooks across ring-test / wield / proof / hone:
  table-driven `go test` + race detector, JUnit via mvn/gradle + surefire
  report reading, `cargo test` variant-matching; httptest / MockMvc /
  axum-test in-process QA; load discipline per runtime (release builds
  enforced for Go/Rust, ≥60s JIT warm-up for JVM, pprof / jcmd / RSS+fd
  monitoring hooks); `go test -bench` + benchstat, JMH-or-JFR, criterion
- Mixed-repo detection: `also=` hint when multiple manifests present —
  skills ask instead of trusting first-match precedence
- Load clients documented as language-agnostic (autocannon targets any HTTP
  service); never install tools into the user's project

## 0.2.0 — unreleased

Adoption discipline + TDD, closing the gaps vs superpowers.

- **using-smithy** meta-skill: skill routing table, priority rules,
  rationalization red-flags — injected into every session by the
  SessionStart hook (superpowers' adoption pattern)
- **jig** skill + **jigsmith** agent: first-class, choosable TDD path
  (RED→GREEN→REFACTOR per requirement, verbatim evidence, commit-per-stage,
  ordering verified by the inspector); `implementation.tdd: ask|always|never`
  config, editable via calibrate; bug fixes in anneal are always TDD
- Agents renamed to their skill verbs: `implementor→forger`,
  `code-reviewer→inspector`, `debugger→annealer`, `tester→temperer`
- Process-heavy skills expanded (budget raised 150→300 lines): mandatory
  checklists, red-flag rationalization tables, orchestrator process graph,
  decomposition rules in blueprint, finding-evaluation rules in inspect
- Review fixes: portable sed in review-package.sh, python3 guard + one-time
  malformed-config warning in routing.sh, PARTIAL ledger status, corrected
  forge example paths

## 0.1.0 — unreleased

Initial release.

- 13 skills: `smithy` (orchestrator), `assay`, `blueprint`, `forge`,
  `inspect`, `anneal`, `temper`, `ring-test`, `wield`, `proof`, `hone`,
  `handover`, `calibrate`
- 4 agents: `implementor`, `code-reviewer`, `debugger`, `tester`
- Dynamic model routing (`docs/smithy/config.json` + per-dispatch model override)
- Per-project memory: `docs/smithy/` (STATE.md, ledger, decisions, jobs)
- SessionStart hook: surfaces project state on session start
