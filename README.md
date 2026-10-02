# smithy 🔨

Smithy is a Claude Code plugin that runs a **full development pipeline**:
research → plan → build → review → debug → test. The names come from a blacksmith's shop: you *assay* the ore, draw a *blueprint*, *forge* the piece, *inspect* it, *anneal* out the defects, and *temper* it until it holds. Three core ideas:

- **Never assume.** When something is unclear, smithy asks you. It does not guess.
- **Per-project memory.** Every job leaves a spec, a plan, reports and an event log on disk, so work survives a crash.
- **Model routing.** You choose which model and effort level each role uses (planning, review, …), per project or for all projects.

## Install

```
/plugin marketplace add dyasnurhakim/smithy-claude
/plugin install smithy@smithy-claude
```

Or from a local clone:

```
/plugin marketplace add /path/to/smithy-claude
/plugin install smithy@smithy-claude
```

Restart the session (or `/plugin` → enable). A SessionStart hook then announces smithy and its routing rules in every new session.

### Codex CLI / Codex App (GPT-5.6)

Smithy also runs under OpenAI's Codex. Two ways in. **1. Codex plugin marketplace** (once listed):

```
/plugins        # in Codex — search "smithy", Install Plugin
```

Codex plugins install from the [official marketplace](https://github.com/openai/plugins); a listing needs a submission PR. The repo is ready for it: `.codex-plugin/plugin.json` is the manifest, and `scripts/sync-to-codex-plugin.sh` builds the plugin tree and opens the PR from your fork (`--stage-only` builds it locally first).
**2. Manual (works today):** clone the repo. Codex reads `AGENTS.md` (the entry file) on its own.

Either way: turn on subagents (`~/.codex/config.toml` → `[features] multi_agent = true`) and set `"harness": "codex"` once with the calibrate skill. Models then translate on their own: flagship roles get `sol`, workhorse roles `terra`, simple jobs `luna`; older ids (`gpt-5.5`, `gpt-5.4`, …) can be set per role. **No hooks run under Codex**, so the git guard, routing and the MCP "ask first" rule are rules in the prompt, not enforced. Details: `references/harness.md`. **Status:** built to match a proven adapter, but not yet live-tested under Codex and not yet submitted to the marketplace.

## Usage

**One command** runs the whole pipeline, with an approval gate between phases. **Or run each phase yourself** — every skill works on its own (see [What each skill needs](#what-each-skill-needs)):

```
/smithy build a password-reset flow with email verification
/smithy:assay add rate limiting to the public API   # research → spec (asks about every unclear point)
/smithy:blueprint                                   # spec → plan + one brief per task
/smithy:forge                                       # build task by task, then ONE review of the job
/smithy:guild                                       # production-readiness panel
/smithy:temper                                      # full test pass → READY / NOT READY
/smithy:handover                                    # summary for the next session
/smithy:strike fix the 3 findings from the review   # small known changes, no spec needed
/smithy:anneal "POST /orders returns 500 when the cart is empty"   # find the cause before any fix
/smithy:jig implement the discount calculator       # test-first, one clean commit per task
/smithy:calibrate review=sonnet/medium              # change model routing
```

### Example — a full run

```
you   > /smithy add CSV export to the reports page

ASSAY      asks instead of guessing: "Which columns? All report types?
           Max rows — stream or cap? Who may export?"
           → $SMITHY_MEM/jobs/csv-export/spec.md        (open questions: none)
GATE       "Spec ready — approve, revise, or abort?"            [you: approve]
BLUEPRINT  4 tasks, each step with a check:
           "2. Add /reports/:id/export → verify: curl returns text/csv"
           → plan.md + briefs/task-1..4.md
GATE       "Approving this plan allows its task commits."       [you: approve]
FORGE      task-1..4: jigsmith writes failing tests (RED), then code (GREEN),
           self-checks, makes ONE commit per task. tdd-snap pictures prove
           the order. Then ONE inspector reviews the whole job (BASE..HEAD):
           APPROVED.
GUILD      diff touches UI + API → engineer, security, qa, uiux, end-user,
           product review in parallel.
           NOT_READY — security: export is missing the role check (Critical).
           → /smithy:strike fixes it (bug → test first) → PRODUCTION_READY
TEMPER     ring-test PASS · wield 91/100 PASS · proof skipped (no SLO change)
           → READY
GATE       "Ship it?"                                           [you: approve]
           → commit grant removed. A push still needs its own yes.
```

Everything the run made lives in `$SMITHY_MEM` (see [Per-project memory](#per-project-memory)). Kill the session at any point: `/smithy` finds its place again from the ledger, not from memory.

## Skills

Every skill has a plain alias: `/smithy:plan` = `/smithy:blueprint`, `/smithy:qa` = `/smithy:wield`, and so on.

| Skill | Alias | What it does |
|---|---|---|
| `smithy` | `pipeline` | Runs the whole pipeline, with gates between phases |
| `assay` | `research` | Explores the code; turns every guess into a question; writes a spec |
| `blueprint` | `plan` | Spec → plan where every step has a check, plus one brief per task |
| `forge` | `implement` | Builds task by task (each self-checks, one commit), then ONE review of the job |
| `jig` | `tdd` | Test-first: failing tests, then code, then one clean commit per task |
| `inspect` | `code-review` | Two verdicts: matches the spec? good code? Each finding has severity and confidence 1–10 |
| `guild` | `review-panel` | Persona reviewers in parallel → one PRODUCTION_READY / NOT_READY verdict |
| `commission` | `personas` | Test personas from your system's real user roles |
| `pattern` | `design` | Design system with visual previews → `DESIGN.md` |
| `burnish` | `design-review` | Screenshots the live UI, judges it against `DESIGN.md`, makes small fixes with before/after proof |
| `strike` | `fix` | Small known changes and review/QA fixes: mini plan → one yes → build → targeted tests → one review |
| `anneal` | `debug` | Reproduce → find the root cause → approved minimal fix + regression test |
| `temper` | `test` | Runs the four test skills below → one READY / NOT READY verdict |
| `ring-test` | `unit-test` | Unit tests per the stack playbook |
| `wield` | `qa` | QA as a user: screenshots, 0–100 health score, trend vs the last run |
| `proof` | `stress-test` | Load test against thresholds YOU set (never invented) |
| `hone` | `perf-test` | Benchmarks (median of ≥3 runs) and profiles; recommendations only |
| `handover` | `handoff` | Summary with evidence so the next session starts fast |
| `calibrate` | `config` | View/edit models, effort, TDD settings, gates, memory location |
| `using-smithy` | — | The router: which skill when. Injected into every session |

## What each skill needs

Every skill starts with `scripts/start.sh <skill>`. It finds (or creates) the memory folder, reads STATE.md and picks the job. A missing input from *another skill* never stops a skill: it falls back (asks a few questions, writes a small version, confirms it) and goes on. Only the "must have" column can stop a skill — there is nothing to test or review without it. Skills that need a running app read its start command and URL from one `run:` line in `decisions.md`; the first one to need it asks you once and saves it.

| Skill | Must have | Uses if present (else falls back) |
|---|---|---|
| smithy, assay, strike | your request | STATE.md, past specs, memory lookups |
| blueprint | your request | `spec.md` — else asks a few questions first |
| forge, jig | your request | `plan.md` + briefs — else writes one brief and confirms it |
| inspect, guild | a diff (`--base <ref>`) | the plan — else a short brief from your words |
| wield | a runnable app (the `run:` line) | personas, success criteria in the spec or plan |
| proof | a running LOCAL service + your thresholds | the `run:` line |
| burnish | a running LOCAL UI + Playwright | `DESIGN.md`, the `run:` line |
| hone / ring-test | something to measure / code to test | a baseline / the stack playbook |
| anneal | a failure and a way to reproduce it | earlier reports, the ledger |
| calibrate, handover, commission, pattern | nothing else | STATE.md, the ledger |

## How a job is built and reviewed

```
before (≤0.13)                               now (0.14)
review after EVERY task                      self-check per task, ONE review per job
commit per TDD stage (test → feat → refactor) ONE commit per task; pictures prove the order
```

- **Self-check.** Each task ends with a short checklist: each requirement → `file:line`; only brief files touched; checks green; no debug code; TDD proof `OK`.
- **One review.** After all tasks, one inspector reviews the whole job (`BASE..HEAD`). It does not trust the agents' reports; it checks them.
- **Fix rounds.** A REJECTED review gets a fix round, and only the fix diff is reviewed again. After `implementation.max_fix_cycles` rounds (default 2), smithy stops and asks you.
- **Fixes from reviews and QA** go to `/smithy:strike`. It needs no plan. Bug items go test-first.

### TDD (test-driven development: tests first, then code)

`scripts/tdd-snap.sh` takes a *picture* of the working folder after each stage. A picture is a git tree object (a saved snapshot of the files). It is not a commit, so HEAD, branches and the index are never touched. `tdd-snap.sh verify` then checks the order: RED added a test, GREEN added code, nothing changed after the last picture. The controller runs `verify` itself right after each task (inside the task's worktree for parallel work); it does not trust the agent. The final review re-checks the order with `verify --audit`. The full TDD rules live in one place: `skills/jig/SKILL.md`.

| Setting (`implementation.*`) | Values | What it changes |
|---|---|---|
| `tdd` | **`ask`** · `always` · `never` | Use the test-first agent (jigsmith) or the plain forger. Bug fixes are always test-first |
| `tdd_level` | `minimal` · **`balanced`** · `max` | How many tests. `max` works one requirement at a time. Fewer tests, never a different order |
| `tdd_commits` | **`clean`** · `stages` | `clean` = one commit per task, tests + code together. `stages` = a commit per stage. Old names still work: `git` → `stages`, `local` → `clean` |
| `max_fix_cycles` | number, **2** | Fix rounds after the review before smithy asks you. `0` = ask at once |

## Parallel execution and state lanes

Blueprint marks tasks `∥ batch-X` only when it can show they touch different files. **Forge asks you per batch:** parallel or one by one.

```
           ┌─ worktree task-2 ─ agent ─ self-check ─┐
integrate ─┤                                         ├─▶ integration branch
           └─ worktree task-3 ─ agent ─ self-check ─┘          │ checks + test suite here
                                                               ▼ green
                                        land on your branch ─▶ (one review later)
```

- One git worktree (a second checkout of the repo) per task; all agents start at once. Task branches merge into an **integration branch** first; only a green integration lands on your branch.
- A merge conflict means the batch was not really separate: smithy stops and runs that task alone. It never resolves conflicts by hand. Nothing is pushed. Smithy removes its own worktrees at batch end; worktrees *you* made are never removed.

**State lanes.** A worktree keeps the *code* apart, but not smithy's own state. So each worktree also gets a **lane**: its own STATE.md, ledger and decisions under `$SMITHY_MEM/lanes/<job>-<task>/`. Inside a lane, reading the ledger shows the project's events too; writes stay in the lane. When the work lands, `scripts/lane.sh merge` folds the events back in time order (`abandon` drops rolled-back work). This also lets two whole pipelines run in one repo: start the second from its own worktree (`worktree.sh create <job-b> pipeline`). Each lane keeps its own base sha. There is one commit grant per project, so a pipeline only removes a grant that names its own job.

## Agents

| Agent | Default model | Can write files? | Role |
|---|---|---|---|
| `forger` | sonnet | yes | Builds ONE task brief; small exact changes; self-check; one commit |
| `jigsmith` | sonnet | yes | Test-first builder; proves the order with tdd-snap; one commit |
| `inspector` | opus | no (read-only) | Two-verdict review of the whole job; checks every claim |
| `annealer` | opus | no (read-only) | Finds the root cause with evidence; never fixes |
| `temperer` | sonnet | test files only | Writes and runs tests; never touches production code |

**Tools.** Agents have no `tools:` allow-list. They get your installed tools — MCP lookup tools included — minus a `disallowedTools` deny-list: no agent may dispatch agents, run skills, schedule jobs or publish artifacts, and the read-only two also lose Write and Edit. Why a deny-list: in Claude Code 2.1.x an `mcp__*` wildcard in `tools:` grants nothing (tested live), so an allow-list would cut agents off from MCP. Trade-off: a new built-in tool is allowed until it is added to the list. The default model is overridden by your routing config.

**Inter-agent envelope.** Every brief, report and verdict starts with a small YAML header (`references/envelope.md`): kind, job, unit, status, confidence, `key_facts`, `concerns`, `next_action`. Open key facts are copied into the next brief, so important facts are not lost between agents. `scripts/envelope.sh` reads and checks it.

## Lookup tools

Agents and skills may use MCP tools (tools from servers you installed) to look things up faster than grep. **None are required**; without them smithy uses Read/Grep and says so.

| Need | Tools that fit | Without one |
|---|---|---|
| memory — "did we do this before?" | claude-mem | ledger, decisions.md, `git log` |
| graph — callers, structure, impact | understand-anything, graphify, claude-mem `smart_outline` | Grep + Read |
| docs — library API for your version | context7 or another docs server | the installed package source |

- **Reading is free. Changing asks first.** A tool that sends, creates, updates or deletes needs your yes, even when your own rules name it. **Small budget:** per run, at most 1 search, 1 timeline, 3 full records.
- **A lookup is a lead, not a fact.** Trust order: code and `git log` > ledger > lookup results. Cloud sync and third-party providers are never turned on.

## Hooks — three guards

Prompt rules can be talked around; a hook's exit code cannot. Each hook fails in a different direction on purpose. All three act only in projects smithy manages. Your own `CLAUDE.md` rules still win over smithy wherever they conflict (creed §0).

| Hook | Watches | When unsure | Does |
|---|---|---|---|
| `scripts/guard.sh` | Bash | **blocks** | Stops unsafe git and destructive commands |
| `scripts/route-guard.sh` | subagent dispatch | **lets it through** | Fixes the model and effort to match your config |
| `scripts/mcp-guard.sh` | MCP tool calls (`mcp__…`) | **asks you** | Makes Claude Code ask before an MCP tool changes anything |

**guard.sh — git and destructive commands.**
- `git push` needs a live yes per push. `git commit` needs the job's plan approval (a commit grant, removed when the job ends).
- History rewrites (`--amend`, `rebase`, `reset --hard`, `branch -D`, `clean -f`, force flags): always blocked.
- Destructive commands need your yes for that one command (`guard.sh allow-once` makes a one-use token): cloud deletes (`aws`, `gcloud`, `az`, `fly`, `heroku`, `vercel`), `terraform`/`pulumi`/`cdk destroy`, `docker rm|prune|compose down`, `kubectl delete`, `helm uninstall`, `DROP`/`TRUNCATE`/`DELETE` without `WHERE`, migration resets, `rm -rf` on absolute/`~`/`..` paths, `find -delete`, `rsync --delete`, `dd`, `mkfs`.
- It targets destruction, not work: `DELETE … WHERE …`, `docker build`, `kubectl get`, `terraform plan` all pass.

**route-guard.sh — routing that agents cannot ignore.** It reads each smithy dispatch, finds the role from the agent (forger/jigsmith → implementation, inspector → review, annealer → debugging, temperer → testing), and sets the model and the effort banner (a line in the prompt that sets how hard to think) to match config. Each fix is announced as `[smithy-route-guard] …`. On any error it lets the dispatch through: a slightly wrong model is better than a dead dispatch. `bash scripts/route-guard.sh table` shows what each agent will run as.

**mcp-guard.sh — MCP changes ask first.** It reads the tool name from the call (a real JSON parse, so text inside the tool's input cannot fool it). A "change" word (send, create, update, delete, resolve, …), a bare `query` or anything with `sql` (SQL can write), or no known word → Claude Code asks you. A read word (search, get, list, read, …) → it says nothing and your normal permissions decide. It never says "allow". In a run with no one to ask (`claude -p`), "ask" means the call is refused.

## Model routing

Each role maps to a model and an effort. Config merges three layers, lowest first:

| Layer | File | Scope |
|---|---|---|
| defaults | `<plugin>/defaults/config.json` | ships with smithy |
| global | `$SMITHY_HOME/config.json` (default `~/.smithy`) | every project on this machine |
| project | `$SMITHY_MEM/config.json` | this project only |

Merging is per key, so a global model and a project effort can combine on one role. The defaults name **tiers**, not models: planning, review and debugging = `flagship`/`high`; research, implementation and testing = `workhorse`/`medium`; mechanical = `fast`/`low`.

Change it with `/smithy:calibrate`, or in one line: `/smithy:calibrate review=fable/xhigh` (add `--global` for all projects). Effort is `low | medium | high | xhigh | max`; it becomes a banner in the agent's prompt, not an API setting.

**Model names survive new releases.** The model list is data (`defaults/models.json`), not code. A model value can be:

1. a **tier**: `flagship` / `workhorse` / `fast`. Always maps to today's model for that tier.
2. a **family**: `fable`, `opus`, `sonnet`, `haiku` (Claude); `sol`, `terra`, `luna` (Codex). Across harnesses it maps by tier, so `opus` under Codex becomes `sol`.
3. **any id that matches the harness's patterns**: `claude-*`, `opus*`, … or `gpt-*`, `o[0-9]*`, `codex*`. Old ids and future ones (`claude-opus-6`) work with no smithy update.
4. `inherit`: use the agent's own default.

A new family goes in `$SMITHY_HOME/models.json`. `scripts/routing.sh --models` lists what your harness accepts; `--dump` shows the table in effect and where each value came from. The list only checks spelling; **calibrate runs a live test before it saves a model**, because what is available depends on your account.

## Personas

Reviews can fan out to **persona reviewers** running in parallel. **Masters** ask "is it built right?" (engineer, security, QA, UI/UX, designer, SRE). **Patrons** ask "is it the right thing?" (end-user, product, marketing, support). `/smithy:guild` picks the roster from the diff (engineer + security always). **PRODUCTION_READY** needs no Critical or High findings. Every finding needs proof: `file:line` + code, command output, or a screenshot (UI personas drive the app with Playwright). No proof → `cannot-verify`, not a finding. The verdict is written twice: `guild-verdict.md` for people, `guild-verdict.json` for CI and trend tools.

Personas also shape the other agents (`references/persona-modes.md`): build rules for the forger/jigsmith, a test lens for the temperer, an investigation lens for the annealer. `/smithy:commission` adds **project personas** (your real roles, e.g. patient, receptionist, admin) that wield uses for QA per role.

## Supported stacks

The test skills detect the stack from its manifest files (`scripts/stack-detect.sh`) and follow a playbook per stack. Several stacks in one repo → smithy asks which one the job is for. An unknown stack → generic rules and a test command you confirm, never a guessed toolchain.

| Stack | Detected via | Unit | QA | Stress | Perf |
|---|---|---|---|---|---|
| TS/JS | package.json | vitest/jest | Playwright / supertest | autocannon, k6 | `node --cpu-prof`, vitest bench |
| Python | pyproject / requirements | pytest | httpx test clients | locust | cProfile, pytest-benchmark |
| Go | go.mod | `go test` (+`-race`) | httptest | autocannon + pprof | `go test -bench` + pprof |
| Java/JVM | pom.xml, build.gradle | JUnit | MockMvc / TestRestTemplate | autocannon + JFR | JMH or JFR |
| Rust | Cargo.toml | `cargo test` | axum/actix test utils | autocannon + RSS monitoring | criterion / perf |

## Per-project memory

Every skill reads and writes one folder, `$SMITHY_MEM`:

```
$SMITHY_MEM/
├── STATE.md       ≤40-line index: active job, phase, base sha, next step
├── config.json    this project's config (only what differs)
├── ledger.md      event log, append-only, written only by ledger.sh
├── decisions.md   decision log, plus the `run:` line (how to start your app)
├── lanes/         one folder per parallel task (see state lanes)
└── jobs/<slug>/   spec.md · plan.md · briefs/ · reports/ · handoff.md
```

Everyday skills read the short `references/memory-card.md`; the full rules are in `references/memory.md`. **It does not have to live in your repo.** Some repos clean or regenerate `docs/`, which would wipe the ledger. `scripts/paths.sh` picks the folder by the first rule that matches:

| # | Rule | Set by |
|---|---|---|
| 1 | `$SMITHY_MEM_DIR` env var | you, per session |
| 2 | `<repo>/.smithy-path` pointer file | `init-memory.sh --at <dir> --pointer` |
| 3 | `$SMITHY_HOME/projects.tsv` — fully outside the repo | `init-memory.sh --external` |
| 4 | `<repo>/docs/smithy/` if it already exists | older projects keep working |
| 5 | global `memory.location` (`repo` / `external`) | `/smithy:calibrate` |

The first time, smithy **asks** where memory should live. `scripts/paths.sh --dump` shows the folder and the rule that chose it. All git worktrees use the main worktree's memory, so there is one ledger per project. **Recovery rule:** trust STATE.md, the ledger and `git log` over recollection. After a crash or compaction, work resumes at the first unit without a DONE/APPROVED line.

## The creed

Every skill and agent follows `references/creed.md`. The main points:

- **Never assume.** Unclear → a question or a stated recommendation.
- **Evidence before claims.** Cite `file:line`, command output or a ledger line.
- **Small, exact changes.** Every changed line traces to the request.
- **Work toward a check.** Every plan step has `→ verify: <check>`.
- **Finish the job.** Done only when every check passes; anything left is listed, never hidden.
- **Plain voice.** Simple English, short but complete, a picture where it helps. **Lookup tools** are helpers, read-only by default.

## Working on smithy

Every `tests/*.sh` must stay green (11 suites). `tests/skill-lint.sh` checks each SKILL.md (layout per `references/skill-shape.md`, size, referenced files exist), the agents' deny-lists, and that the three manifests agree on the version. To try a change live without touching your installed copy: `claude --plugin-dir /path/to/smithy-claude --settings '{"enabledPlugins":{"smithy@smithy-claude":false}}'`.

## Credits

Built on proven patterns from [superpowers](https://github.com/obra/superpowers) (file-handoff dispatch, progress ledger, two-verdict review), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (agent shape, verification report, handoff template), gstack (QA tiers, health scores, confidence calibration), and [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (the constitution). MIT licensed.
