# smithy 🔨

A self-contained Claude Code plugin that runs a **full development pipeline** — research → planning → implementation → review → debugging → testing — with a hard "never assume, never hallucinate" constitution, per-project memory, and **dynamic model routing** (choose which Claude model and effort level each pipeline role uses, per project).

Blacksmith-themed: you *assay* the ore, draw a *blueprint*, *forge* the piece, *inspect* it, *anneal* out the defects, and *temper* it until it holds.

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

Restart the session (or `/plugin` → enable) and you're set — the SessionStart hook announces smithy and its routing rules in every new session.

### Codex CLI / Codex App (GPT-5.6)

Smithy runs under OpenAI's Codex too. Two ways in:

**Via the Codex plugin marketplace** (once listed — the repo ships marketplace-ready):

```
/plugins        # in Codex — search "smithy", Install Plugin
```

Codex plugins install from the [official marketplace](https://github.com/openai/plugins); listing requires a submission PR. This repo is packaged for it: `.codex-plugin/plugin.json` (interface manifest), skills surfaced natively, and `scripts/sync-to-codex-plugin.sh` stages the exact plugin tree and opens the submission PR from your fork (`--stage-only` to inspect the tree locally first).

**Manual (works today):** clone the repo — Codex picks up `AGENTS.md` (the harness entrypoint) automatically.

Either way: enable subagents (`~/.codex/config.toml` → `[features] multi_agent = true`) and set the harness once per project — `"harness": "codex"` in `docs/smithy/config.json` (or via the calibrate skill). Model routing translates automatically: flagship roles get `sol`, workhorse roles `terra`, mechanical `luna`; older generations (`gpt-5.5`, `gpt-5.4`, …) can be set per role as explicit ids. Full adaptation rules (dispatch mapping, what degrades — notably: plugin hooks don't run there, so the git guard is prompt-level) live in `references/harness.md`. **Status: structurally faithful to the proven superpowers adapter — not yet live-tested under Codex, and not yet submitted to the marketplace (smithy is under active development; the sync script runs when it's time).**

## Usage

### The one command

```
/smithy build a password-reset flow with email verification
```

That runs the whole pipeline with approval gates. You'll be asked questions instead of smithy assuming answers — that's the core design.

### Or drive each phase yourself

```
/smithy:assay add rate limiting to the public API     # research → spec (asks about every ambiguity)
/smithy:blueprint                                     # spec → verify-annotated plan + task briefs
/smithy:forge                                         # implement task-by-task (review after each task)
/smithy:guild                                         # production-readiness persona panel
/smithy:temper                                        # full test pass → READY / NOT READY
/smithy:handover                                      # evidence-cited summary for the next session
```

Useful standalone:

```
/smithy:anneal "POST /orders returns 500 when the cart is empty"   # RCA before any fix
/smithy:jig implement the discount calculator                      # test-first (RED→GREEN, evidence enforced)
/smithy:wield                                                      # QA the app like a user (health score 0-100)
/smithy:commission                                                 # define who uses this system → test personas
/smithy:calibrate review=sonnet/medium                             # change model routing per project
```

### Example workflow — what a full run actually looks like

```
you    > /smithy add CSV export to the reports page

ASSAY    smithy restates the goal, then asks instead of assuming:
         "Which columns? All report types or just tabular ones? Max rows —
         stream or cap? Who may export (role check)?"
         → docs/smithy/jobs/csv-export/spec.md   (open questions: none)

GATE     "Spec ready — approve, revise, or abort?"           [you: approve]

BLUEPRINT 4 tasks, every step verify-annotated:
         "2. Add /reports/:id/export endpoint → verify: curl returns
          text/csv with header row"
         → plan.md + briefs/task-1..4.md
GATE     "Approving this plan authorizes its task commits."  [you: approve]
         → commit grant written (guard hook now allows task commits)

FORGE    task-1: jigsmith (TDD mode) — failing test committed (RED),
         minimal impl (GREEN), inspector reviews the diff against the brief:
         APPROVED. task-2 … task-4 likewise. One rejected task gets one fix
         cycle, re-review, APPROVED.

GUILD    diff touches UI + API → roster: master-engineer, master-security,
         master-qa, master-uiux, patron-end-user, patron-product (parallel).
         Verdict: NOT_READY — security: export endpoint missing the role
         check the spec promised (Critical, confidence 9).
         → fix brief → forge → security re-reviews → PRODUCTION_READY

TEMPER   ring-test PASS · wield 91/100 PASS · proof skipped (no SLO change)
         → temper-summary.md: READY

GATE     "Ship it?"                                          [you: approve]
         → commit grant revoked. Push? Only if you say so — a push needs
         its own yes, every time.

/smithy:handover → handoff.md; next session resumes from the ledger even
after a crash or compaction.
```

Everything the run produced lives in your repo under `docs/smithy/` — spec, plan, briefs, every agent report, an append-only ledger, and a ≤40-line STATE.md. Kill the session at any point; `/smithy` recomputes its position from the ledger, not from memory.

## Skills

| Skill | Alias | What it does |
|---|---|---|
| `/smithy:smithy` | `pipeline` | **Orchestrator** — runs the whole pipeline with approval gates at phase boundaries |
| `/smithy:assay` | `research` | **Research** — explores the codebase, converts every would-be assumption into a question or recommendation, writes a spec |
| `/smithy:blueprint` | `plan` | **Planning** — turns the spec into a verify-annotated task plan + per-task briefs |
| `/smithy:forge` | `implement` | **Implementation** — dispatches the forger (or jigsmith, in TDD mode) per task, with a review after each task |
| `/smithy:jig` | `tdd` | **TDD implementation** — RED→GREEN→REFACTOR per requirement with verbatim failing-test evidence; forge's `implementation.tdd` config chooses jig vs plain forge |
| `/smithy:inspect` | `code-review` | **Code review** — two verdicts: spec compliance + code quality; findings carry severity and 1–10 confidence |
| `/smithy:guild` | `review-panel` | **Production-readiness panel** — parallel persona reviewers (masters judge craft, patrons judge experience) → one PRODUCTION_READY / NOT_READY verdict |
| `/smithy:commission` | `personas` | **Project personas** — generates test personas from your system's real user roles; powers per-persona QA in wield and the guild's end-user judgment |
| `/smithy:pattern` | `design` | **Design creation** — deliberate style direction with visual previews, tokens, states, motion, voice → `docs/smithy/DESIGN.md`, the design source of truth |
| `/smithy:burnish` | `design-review` | **Design review & improvement** — screenshots the live UI, judges against DESIGN.md (or declared heuristics), then applies surgical fixes with before/after proof |
| `/smithy:strike` | `fix` | **One-shot fixes** — small known changes: lightweight plan → one confirmation → forge (no TDD) → targeted tests → one report |
| `/smithy:anneal` | `debug` | **Debugging** — reproduce → root-cause analysis → approved minimal fix + regression test. Never guess-fixes |
| `/smithy:temper` | `test` | **Testing umbrella** — runs the four test skills below, produces one READY / NOT READY verdict |
| `/smithy:ring-test` | `unit-test` | **Unit tests** (ring test = tapping metal to hear flaws) |
| `/smithy:wield` | `qa` | **QA / functional testing** — severity tiers, 0–100 health score, cross-run trend fingerprints |
| `/smithy:proof` | `stress-test` | **Stress / load testing** (proofing = deliberate overload) — you set the SLOs, it never invents them |
| `/smithy:hone` | `perf-test` | **Performance** — baseline-first benchmarking, median of ≥3 runs, recommendations only |
| `/smithy:handover` | `handoff` | **Session handoff** — evidence-cited summary so the next session resumes with zero re-discovery |
| `/smithy:calibrate` | `config` | **Model routing config** — view/edit which model + effort each role uses, TDD default, gates — like `/config` |
| `/smithy:using-smithy` | — | **Router** — when to use which skill, priority rules, rationalization red-flags. Injected into every session by the SessionStart hook |

Aliases are plain slash commands: `/smithy:plan` = `/smithy:blueprint`, `/smithy:qa` = `/smithy:wield`, etc. Use whichever vocabulary fits your head.

## Parallel execution

Blueprint marks tasks `∥ batch-X` **only with proof of disjointness** (file sets listed in the plan, no cross-imports, no shared scaffolding — default is sequential). A marker is permission to *offer*, not to act: **forge asks you, per batch, parallel or sequential**.

When you choose parallel: one **git worktree + branch per task** (`.smithy-wt-<repo>/` sibling dir), all agents dispatched in a single message, each branch reviewed *before* merging. Task branches merge into an **integration branch first** — the batch's combined verify commands and the test suite run there — and only a verified integration lands on your working branch (`--no-ff`). A merge conflict means the batch was mis-marked — clean abort and escalate, never hand-resolved. Everything stays **local**: no branch is pushed to origin unless you ask (each push needs its own yes). **Smithy always removes its own worktrees when the batch ends** (committed work survives on branches); worktrees *you* created are never auto-removed — it asks whether to clear or leave them.

## Agents

Agent names follow their skill's verb: the *forger* forges, the *inspector* inspects, the *annealer* anneals, the *temperer* tempers, and the *jigsmith* shapes work against a jig (tests written first).

| Agent | Default model | Tools | Role |
|---|---|---|---|
| `forger` | sonnet | Read, Grep, Glob, Bash, Write, Edit | Executes exactly one task brief; surgical changes only |
| `jigsmith` | sonnet | Read, Grep, Glob, Bash, Write, Edit | TDD implementor: failing test first (RED, verbatim output) → minimal code (GREEN) → refactor, commit per stage |
| `inspector` | opus | Read, Grep, Glob, Bash (read-only) | Two-verdict review; does not trust the forger's report; verifies TDD commit ordering |
| `annealer` | opus | Read, Grep, Glob, Bash (read-only) | Root-cause analysis with reproduced evidence; never applies fixes |
| `temperer` | sonnet | Read, Grep, Glob, Bash, Write, Edit | Writes/runs tests; may not touch production source |

## Dynamic model routing

Each pipeline role maps to a model + effort in `docs/smithy/config.json` (project) overriding `defaults/config.json` (plugin):

```json
"routing": {
  "planning":       { "model": "opus",   "effort": "high"   },
  "implementation": { "model": "sonnet", "effort": "medium" },
  "review":         { "model": "opus",   "effort": "high"   },
  "debugging":      { "model": "opus",   "effort": "high"   },
  "testing":        { "model": "sonnet", "effort": "medium" },
  "mechanical":     { "model": "haiku",  "effort": "low"    }
}
```

The model is passed as the Agent tool's per-dispatch `model` parameter (overrides agent frontmatter). Valid models, cheapest to most capable: `haiku` < `sonnet` < `opus` < `fable` (Claude 5 Mythos-class — availability depends on your account), plus `inherit`. Effort maps to an injected prompt banner — it is prompt-level guidance, not an API knob. Edit interactively with `/smithy:calibrate`, or one-shot: `/smithy:calibrate review=fable/high`.

TDD is a first-class, *choosable* path: `"implementation": { "tdd": "ask" | "always" | "never" }` decides whether forge dispatches the `jigsmith` (test-first, with RED→GREEN evidence verified from commit ordering) or the plain `forger`. Bug fixes always go test-first — the regression test is the RED.

## Personas — the guild and its patrons

Reviews can fan out to **parallel persona reviewers** (one inspector agent, different persona overlays):

- **Masters** (craft — is it built right?): engineer, security, QA, UI/UX, designer (identity & distinctiveness — the anti-template judge), SRE
- **Patrons** (experience — is it the right thing?): end-user, product, marketing, support

`/smithy:guild` selects the roster by diff content (engineer + security always; the rest conditional), dispatches them in parallel, dedupes and cross-verifies findings, and issues one verdict: **PRODUCTION_READY** requires both craft and experience clean of Critical/High. `/smithy:commission` adds **project-level personas** (your system's actual roles — e.g. patient, receptionist, admin) that wield uses to run QA flows per role, including cross-persona permission checks.

**Personas overlay every agent, not just reviewers** (`references/persona-modes.md`): the same persona file is a *judgment lens* for the inspector, *build constraints* for the forger/jigsmith (master-engineer rides every implementation task, plus at most one domain specialist), a *test lens* for the temperer (qa on unit tests, end-user/support on QA, sre on stress), and an *investigation lens* for the annealer (picked by symptom domain). Blueprint tags each task brief with its personas automatically.

**Every finding must carry proof.** The inspector's evidence contract: file evidence (`file:line` + the offending excerpt), command evidence (verbatim output), or **screenshot evidence** — when the diff is user-facing and the app is runnable, UI-facing personas (UI/UX, end-user, marketing, support) drive it headlessly with Playwright and save screenshots to `docs/smithy/jobs/<job>/reports/guild-evidence/<persona>/` in your repo. Each finding states *why* it's flagged and *why* it got its severity (tied to the persona's calibration). No proof → it's reported as `cannot-verify`, not as a finding. The verdict ships twice: human-readable `guild-verdict.md` and machine-readable `guild-verdict.json` (findings with fingerprint, severity + reason, evidence path, fix — ready for CI or trend tooling).

## Git guard rails

A deterministic PreToolUse hook (`scripts/guard.sh`) enforces git safety in smithy-managed projects — prompt rules can be rationalized away, exit codes can't:

- `git push` — blocked; needs a live user yes per push (one-shot token)
- `git commit` — blocked unless the job's plan gate was approved (approval = job-scoped commit grant, auto-revoked at job end)
- History rewrites (`--amend`, `rebase`, `reset --hard`, `branch -D`, `clean -f`, force flags) — always blocked
- **Destructive operations** — blocked unless the user approves that specific command (then `guard.sh allow-once` mints a token consumed by exactly one command):
  - *Cloud*: `aws … terminate-instances`/`delete-*`/`s3 rb|rm`, `gcloud … delete`, `gsutil rm|rb`, `az … delete`, `fly destroy`, `heroku destroy|pg:reset`, `vercel remove`
  - *IaC*: `terraform destroy`, `pulumi destroy|stack rm`, `cdk destroy`
  - *Containers*: `docker rm|rmi|prune|volume rm|compose down`, `kubectl delete|drain`, `helm uninstall`
  - *Databases*: `DROP`/`TRUNCATE`/`ALTER … DROP` via any client (psql/mysql/sqlite3/mongo/…), `DELETE FROM` without `WHERE`, `dropdb`, `redis-cli flushall|flushdb`, mongo `dropDatabase`, and migration resets (`prisma migrate reset`, `rails db:drop|reset`, `artisan migrate:fresh|reset`, Django `flush`, `alembic downgrade base`)
  - *Filesystem*: `rm -rf` on absolute/`~`/`..` paths, `find -delete`, `rsync --delete`, `shred`, `dd of=/dev/*`, `mkfs`, `truncate -s 0`
- Non-smithy projects: the hook stands down entirely
- Your own `CLAUDE.md` rules override smithy protocol wherever they conflict (creed §0)

`DELETE FROM logs WHERE created_at < …` passes; `DELETE FROM logs` does not. `docker build`/`compose up`/`kubectl get`/`aws s3 ls`/`terraform plan` all pass — the guard targets destruction, not operations. 57-case test matrix in the repo history.

## Inter-agent envelope

Every brief/report/verdict opens with a machine-readable YAML envelope (`references/envelope.md`): kind, job, unit, status, confidence, `key_facts[]`, `concerns[]`, `next_action`. Controllers copy unresolved key facts forward into the next brief — critical information survives every hop instead of dying in prose. `scripts/envelope.sh` parses and validates it.

## Supported stacks

The testing family (`ring-test`, `wield`, `proof`, `hone`) detects the project's stack from its manifests and follows a per-stack playbook:

| Stack | Detected via | Unit | QA | Stress | Perf |
|---|---|---|---|---|---|
| TS/JS | package.json + lockfiles | vitest/jest | Playwright / supertest | autocannon, k6 | `node --cpu-prof`, vitest bench |
| Python | pyproject/requirements | pytest | httpx test clients | locust | cProfile, pytest-benchmark |
| Go | go.mod | `go test` (+`-race`) | httptest in-process | autocannon + pprof monitoring | `go test -bench` + pprof |
| Java/JVM | pom.xml, build.gradle[.kts] | JUnit via mvn/gradle | MockMvc / TestRestTemplate | autocannon + jcmd/JFR (JIT warm-up enforced) | JMH or JFR |
| Rust | Cargo.toml | `cargo test` | axum/actix test utils | autocannon + RSS/fd monitoring (release builds enforced) | criterion / perf |

Mixed repos (multiple manifests) are flagged with an `also=` hint and the skill asks which stack the job targets. Unknown stacks fall back to generic rules and a confirmed test command — never a guessed toolchain.

## Per-project memory

Every skill reads and updates `docs/smithy/` in your project:

```
docs/smithy/
├── STATE.md        # ≤40-line index: active job, phase, base sha, next step
├── config.json     # routing overrides
├── ledger.md       # append-only event log (one line per event)
├── decisions.md    # append-only decision log
└── jobs/<slug>/    # spec.md, plan.md, briefs/, reports/, handoff.md
```

Recovery rule baked into every skill: **trust STATE.md, the ledger, and git log over recollection.** Sessions (and compactions) can die mid-run; the pipeline resumes at the first unit without a DONE/APPROVED ledger line.

## The creed

Every skill and agent loads `references/creed.md`:

- **Never assume.** Ambiguity becomes a question to the user or an explicit recommendation — never a silent guess.
- **Evidence before assertion.** Claims cite file:line, command output, or a ledger entry.
- **Surgical changes.** Every changed line traces to the request.
- **Success criteria first.** Every plan step carries `→ verify: [check]`.

## Credits

Design synthesizes verified patterns from [superpowers](https://github.com/obra/superpowers) (file-handoff dispatch, progress ledger, two-verdict review), [everything-claude-code](https://github.com/affaan-m/everything-claude-code) (agent shape, verification report, handoff template), gstack (QA tiers, health scores, confidence calibration), and [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills) (the constitution). MIT licensed.
