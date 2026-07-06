# Smithy — Full Dev-Pipeline Claude Code Plugin

## Context

Build a new, fully self-contained Claude Code plugin that runs a complete dev pipeline — research → planning → implementation → review → debugging → QA/stress/perf/unit testing — with a "never assume, never hallucinate; ask or recommend" constitution baked into every skill. Installable from its own GitHub repo via `/plugin marketplace add` + `/plugin install`. Greenfield repo at `/home/dyasnurhakim/claude-agent/smithy/`.

**Confirmed decisions:** self-contained (no dependency on superpowers/ECC/gstack); per-project memory in the target project's `docs/smithy/`; GitHub + own `marketplace.json`; tiered-by-role model routing with a `/calibrate` config skill; both an orchestrator and standalone per-phase skills; approval gates at phase boundaries; testing = 4 separate skills + 1 umbrella; test skills detect stack (first-class TS/JS + Python, generic fallback); blacksmith theme.

## What each reference contributes (and what we improve)

| Reference | Taken | Improved |
|---|---|---|
| **superpowers** | File-handoff dispatch (briefs/reports/diffs passed as *paths*, never pasted); compaction-surviving progress ledger; two-verdict per-task review (spec compliance + code quality); "Do Not Trust the Report" reviewer stance; implementer statuses DONE/DONE_WITH_CONCERNS/NEEDS_CONTEXT/BLOCKED; BASE-sha recorded before dispatch (never HEAD~1); self-install marketplace (`source: "./"`) | superpowers has **no agent files** (uses general-purpose + prompt templates) and **no testing pipeline**. We ship 4 real agents with tool allowlists, and add the full testing family. |
| **ECC** | Agent `.md` frontmatter shape (name/description/tools/model); read-only tools for reviewers; 6-phase verification report (READY/NOT READY); session-handoff template (What Worked / What Didn't / Exact Next Step…) | ECC's models are **static frontmatter** (39 sonnet / 8 opus / 1 haiku, zero routing). We add dynamic per-project routing via config + per-dispatch model override. ECC is 183 skills of sprawl; we ship 13 focused ones. |
| **gstack** | QA severity tiers (Quick/Standard/Exhaustive); weighted 0–100 health score with before/after delta; one-commit-per-fix + revert-on-regression; confidence-calibrated findings (1–10, 9–10 = verified by reading code); cross-run finding fingerprints for trend tracking | gstack's qa SKILL.md is 47KB — unmaintainable. We enforce ≤150-line SKILL.md files with shared references. gstack has no agents/hooks; we get context isolation via real subagents. |
| **karpathy-skills** | The whole constitution: "Don't assume. Don't hide confusion. Surface tradeoffs"; surgical changes ("every changed line traces to the request"); verify-annotated plan steps (`N. [Step] → verify: [check]`); success-criteria-driven loops | It's guidance-only (one 68-line skill). We make it *enforced*: every skill preamble loads the creed; implementor must return NEEDS_CONTEXT instead of guessing; debugger cannot claim a root cause without reproduced evidence. |

**The genuinely novel piece:** dynamic model routing. None of the four references has it. Mechanism (verified): the Agent tool accepts a per-dispatch `model` parameter that overrides agent frontmatter. Effort is not a dispatch parameter, so effort maps to injected prompt text.

## Naming (blacksmith theme — user-selected)

Plugin: **smithy**. Skills invoke as `/smithy:<name>`:

| Skill | Role | Agent dispatched |
|---|---|---|
| `smithy` | Orchestrator: full pipeline w/ gates | (invokes other skills) |
| `assay` | Research → spec (assaying = testing ore) | — (inline; optional haiku scouts) |
| `blueprint` | Planning → verify-annotated plan + task briefs | — (inline) |
| `forge` | Implementation loop | **implementor** |
| `inspect` | Two-verdict code review | **code-reviewer** |
| `anneal` | Debugging / RCA (annealing = healing metal defects) | **debugger** |
| `temper` | Testing umbrella — runs the four below | (invokes test skills) |
| `ring-test` | Unit tests (ring test = tapping metal to hear flaws) | **tester** |
| `wield` | QA / functional (wield the blade like a user) | **tester** |
| `proof` | Stress/load test (proofing = deliberate overload) | **tester** |
| `hone` | Performance/profiling | **tester** |
| `handover` | Session handoff summary | — |
| `calibrate` | Model-routing config editor (/config-style) | — |

## Repo layout (files to create)

```
smithy/
├── .claude-plugin/
│   ├── plugin.json          # name=smithy, version=0.1.0, skills:["./skills/"]; agents+hooks auto-discovered
│   └── marketplace.json     # marketplace "smithy-dev", plugins:[{name:"smithy", source:"./", strict:true}]
├── agents/
│   ├── implementor.md       # tools:[Read,Grep,Glob,Bash,Write,Edit] model:sonnet
│   ├── code-reviewer.md     # tools:[Read,Grep,Glob,Bash] model:opus — read-only, "Do Not Trust the Report"
│   ├── debugger.md          # tools:[Read,Grep,Glob,Bash] model:opus — RCA only, never applies fixes
│   └── tester.md            # tools:[Read,Grep,Glob,Bash,Write,Edit] model:sonnet — test files/configs only
├── skills/<13 dirs>/SKILL.md   # each ≤150 lines; test skills get references/{ts.md,python.md} playbooks
├── references/              # shared via ${CLAUDE_PLUGIN_ROOT}/references/
│   ├── creed.md             # constitution (~70 lines): never assume, surgical changes, evidence before assertion
│   ├── memory.md            # memory protocol: file map, STATE.md template, ledger format, who-writes-what
│   ├── dispatch.md          # routing.sh usage, effort→prompt-text table, brief/report templates, statuses
│   └── stacks.md            # stack detection table + tool matrix (vitest/jest/pytest/playwright/autocannon/k6/locust)
├── scripts/                 # bash, jq-optional
│   ├── ledger.sh            # append/tail/last — single writer for the ledger
│   ├── routing.sh           # role → "model=X effort=Y" (project config over plugin defaults)
│   ├── stack-detect.sh      # lockfile/config sniff → "stack=ts pkg=pnpm unit=vitest e2e=playwright"
│   ├── review-package.sh    # record-base / build BASE..HEAD diff package
│   └── init-memory.sh       # idempotent docs/smithy/ scaffold in target project
├── defaults/config.json     # default routing tiers
├── hooks/
│   ├── hooks.json           # SessionStart (startup|resume|clear|compact)
│   └── session-start.sh     # if docs/smithy/STATE.md exists → emit head -40 + resume hint; else silent
├── README.md  ├── CHANGELOG.md  └── LICENSE (MIT)
```

## Model routing (the novel mechanism)

`defaults/config.json` (project `docs/smithy/config.json` overrides per-key):

```json
{
  "smithy_config_version": 1,
  "routing": {
    "research":       { "model": "sonnet", "effort": "medium" },
    "planning":       { "model": "opus",   "effort": "high"   },
    "implementation": { "model": "sonnet", "effort": "medium" },
    "review":         { "model": "opus",   "effort": "high"   },
    "debugging":      { "model": "opus",   "effort": "high"   },
    "testing":        { "model": "sonnet", "effort": "medium" },
    "mechanical":     { "model": "haiku",  "effort": "low"    }
  },
  "gates": { "pause_between_phases": true, "auto_fix_review_findings": false },
  "testing": { "stack": "auto", "skip": [] }
}
```

- `model`: opus|sonnet|haiku|inherit. Consumed by `routing.sh <role>` → skill passes it as the Agent tool's `model` param (overrides frontmatter — verified mechanism).
- `effort`: low|medium|high|max → injected prompt banner (low="be brief and mechanical" … max="ultrathink; steelman the opposite conclusion"). Documented honestly: effort is prompt-level, not an API dispatch knob.
- `/calibrate`: dump effective table (source column: default vs project) → AskUserQuestion per role → merge-write only changed keys → echo new table. Also parses one-shot args (`/calibrate review=opus/high`).

## Per-project memory (`docs/smithy/` in the target project)

```
docs/smithy/
├── STATE.md          # THE index; ≤40 lines; overwritten (active job, phase, base sha, blockers, next step)
├── config.json       # routing overrides
├── ledger.md         # append-only: "ISO-ts | phase | job | unit | STATUS | artifact-path"
├── decisions.md      # append-only, ≤3 lines per decision
└── jobs/<slug>/
    ├── spec.md  ├── plan.md  ├── briefs/task-N.md
    ├── reports/  (task-N-impl.md, task-N-review.md, rca-*.md, test-*.md, temper-summary.md)
    └── handoff.md
```

Rules: writes only at skill start / unit completion / phase boundary; paths not pasted content; recovery rule in every skill: **"Trust STATE.md, the ledger, and git log over recollection"** — resume = first unit without DONE/APPROVED in ledger.

## Skill behaviors (key gates)

- **smithy** (orchestrator): state machine `ASSAY → gate → BLUEPRINT → gate → FORGE → TEMPER → gate → DONE`; ANNEAL is an on-failure detour. Gates = AskUserQuestion (Approve/Revise/Abort) showing artifact path + 5-line summary. Never does phase work itself; reads only status lines. Resume-from-ledger on entry.
- **assay**: restate request → list every would-be assumption → convert each to a question or explicit recommendation → explore codebase → write spec.md with file:line evidence + open questions. Exit gate: zero unresolved blocking questions.
- **blueprint**: spec → ≤8 tasks, every step `N. [Step] → verify: [check]`; writes per-task briefs; records base sha.
- **forge**: per task dispatch implementor (routing model + effort banner + brief path); handle 4 statuses; build review package; inline inspect; REJECTED ×2 → escalate to user.
- **inspect**: dispatch code-reviewer on package; two verdicts (spec compliance + code quality), findings with severity + confidence 1–10.
- **anneal**: RCA before fix, always. Debugger statuses ROOT_CAUSE_FOUND/INCONCLUSIVE/CANNOT_REPRODUCE; never guess-fix; fix applied via implementor with regression test.
- **temper**: stack-detect → confirm → run selected test skills → `temper-summary.md` with READY/NOT READY verdict.
- **wield**: severity tiers + 0–100 health score + finding fingerprints for cross-run trends; fixes routed to forge as `fix(qa): ISSUE-NNN` one-commit-per-fix.
- **proof**: requires runnable service; asks for thresholds (never invents SLOs; suggested default p99<500ms, 0 5xx @ 50 conc/60s); autocannon/k6 (TS) or locust (Py).
- **hone**: baseline-first benchmarking, ≥3 runs median, recommendations only (edits go through forge).
- **handover**: ECC template (What Worked / What Didn't / Not Tried / Decisions / Blockers / Exact Next Step / Environment); every claim cites a ledger line or command output.

## Build order (each phase verifiable)

1. **Packaging skeleton** — plugin.json, marketplace.json, README, LICENSE, git init. *Verify:* `/plugin marketplace add` (local path) + `/plugin install smithy@smithy-dev` succeeds in a scratch project.
2. **Scripts + defaults/config.json.** *Verify:* run each script against a scratch project (init → files exist; `routing.sh review` → `model=opus effort=high`; ledger round-trip; review-package on 2-commit fixture; stack-detect on vitest + pytest fixtures).
3. **references/*.md + agents/*.md.** *Verify:* dispatch implementor with a toy brief + haiku override; report file appears in required format.
4. **calibrate + handover** (smallest real skills, exercise config + memory end to end). *Verify:* calibrate change survives `routing.sh --dump`; handover produces template-complete handoff.md.
5. **assay, blueprint, forge, inspect.** *Verify:* manual chain on a trivial feature in a fixture repo; inspect catches a planted spec violation; ledger tells the full story.
6. **anneal.** *Verify:* plant a bug; RCA-before-fix ordering holds; regression test lands.
7. **ring-test → wield → proof → hone → temper.** *Verify:* temper on vitest fixture + pytest fixture; generic fallback on bare repo.
8. **smithy orchestrator + SessionStart hook.** *Verify:* full run with gates; kill mid-FORGE, confirm resume picks correct task; hook banner appears.
9. **Polish + publish** — README catalog, CHANGELOG, `wc -l` audit (SKILL.md ≤150 lines), create GitHub repo, push, clean-machine install from GitHub URL. (Commit/push only with per-action permission per user rules.)

## Risks & mitigations

1. Skill bloat (gstack 47KB failure) → hard ≤150-line budget, shared references, `wc -l` audit in phase 9.
2. Orchestrator context exhaustion → never does phase work, file handoffs only, deliberate `/clear`-after-gate guidance, resume-from-ledger.
3. Routing config drift → single reader (routing.sh) with enum validation + warn-and-default; `/calibrate` sole writer, preserves unknown keys.
4. Memory bookkeeping overhead → caps (STATE ≤40 lines, 1-line ledger entries, boundary-only writes).
5. Install friction → mirror superpowers' proven `source:"./"` + `strict:true`; all paths via `${CLAUDE_PLUGIN_ROOT}`; clean-install tests in phases 1 and 9.

## Open items (confirm during build, not blockers)

- GitHub username/org + repo visibility (public/private) — needed at phase 9 push time; **not assumed** (email suggests but does not confirm `fazamuhammad`).
- License MIT assumed (all four references are MIT); flag if you want otherwise.
- Per brainstorming flow: the validated design will also be saved into the smithy repo itself as `docs/superpowers/specs/2026-07-06-smithy-plugin-design.md` in phase 1.

## Verification (end-to-end)

Final acceptance: on a clean scratch project, install smithy from the local marketplace, then run `/smithy` on a small real feature (e.g. add a validated endpoint to a fixture Express/FastAPI app) — pipeline must produce spec, plan, implemented+reviewed commits, temper summary with health score, and a handoff; kill and resume mid-run once; `/calibrate` must visibly change which model a dispatch uses.

---

## Amendments — v0.2.0 (2026-07-06, post-review)

Gap analysis vs superpowers (adoption discipline, process pedagogy, TDD) led to:

1. **Agents renamed to skill verbs**: implementor→forger, code-reviewer→inspector,
   debugger→annealer, tester→temperer. New agent: **jigsmith** (TDD implementor).
2. **TDD is first-class and choosable**: new `jig` skill + jigsmith agent
   (RED→GREEN→REFACTOR per requirement, verbatim evidence, commit per stage,
   ordering verified by inspector from git log). Config `implementation.tdd:
   ask|always|never`; anneal fixes are always TDD (regression test = RED).
3. **using-smithy meta-skill**, injected every session by the SessionStart hook
   (superpowers' adoption pattern): routing table, priority rules, red-flag
   rationalization table.
4. **SKILL.md budget raised 150→300 lines** (user decision) — process-heavy
   skills (smithy, assay, forge, anneal, blueprint, inspect) gained mandatory
   checklists, red-flag tables, decomposition/finding-evaluation rules, and a
   dot process graph in the orchestrator.
5. End-of-branch review fixes (v0.1.0): portable sed, python3 guard + one-time
   malformed-config warning, PARTIAL ledger status, forge path corrections.
