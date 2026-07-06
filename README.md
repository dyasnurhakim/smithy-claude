# smithy 🔨

A self-contained Claude Code plugin that runs a **full development pipeline** — research → planning → implementation → review → debugging → testing — with a hard "never assume, never hallucinate" constitution, per-project memory, and **dynamic model routing** (choose which Claude model and effort level each pipeline role uses, per project).

Blacksmith-themed: you *assay* the ore, draw a *blueprint*, *forge* the piece, *inspect* it, *anneal* out the defects, and *temper* it until it holds.

## Install

```
/plugin marketplace add dyasnurhakim/smithy
/plugin install smithy@smithy-dev
```

Or from a local clone:

```
/plugin marketplace add /path/to/smithy
/plugin install smithy@smithy-dev
```

## Skills

| Skill | What it does |
|---|---|
| `/smithy:smithy` | **Orchestrator** — runs the whole pipeline with approval gates at phase boundaries |
| `/smithy:assay` | **Research** — explores the codebase, converts every would-be assumption into a question or recommendation, writes a spec |
| `/smithy:blueprint` | **Planning** — turns the spec into a verify-annotated task plan + per-task briefs |
| `/smithy:forge` | **Implementation** — dispatches the implementor agent per task, with a review after each task |
| `/smithy:inspect` | **Code review** — two verdicts: spec compliance + code quality; findings carry severity and 1–10 confidence |
| `/smithy:anneal` | **Debugging** — reproduce → root-cause analysis → approved minimal fix + regression test. Never guess-fixes |
| `/smithy:temper` | **Testing umbrella** — runs the four test skills below, produces one READY / NOT READY verdict |
| `/smithy:ring-test` | **Unit tests** (ring test = tapping metal to hear flaws) |
| `/smithy:wield` | **QA / functional testing** — severity tiers, 0–100 health score, cross-run trend fingerprints |
| `/smithy:proof` | **Stress / load testing** (proofing = deliberate overload) — you set the SLOs, it never invents them |
| `/smithy:hone` | **Performance** — baseline-first benchmarking, median of ≥3 runs, recommendations only |
| `/smithy:handover` | **Session handoff** — evidence-cited summary so the next session resumes with zero re-discovery |
| `/smithy:calibrate` | **Model routing config** — view/edit which model + effort each role uses, like `/config` |

## Agents

| Agent | Default model | Tools | Role |
|---|---|---|---|
| `implementor` | sonnet | Read, Grep, Glob, Bash, Write, Edit | Executes exactly one task brief; surgical changes only |
| `code-reviewer` | opus | Read, Grep, Glob, Bash (read-only) | Two-verdict review; does not trust the implementor's report |
| `debugger` | opus | Read, Grep, Glob, Bash (read-only) | Root-cause analysis with reproduced evidence; never applies fixes |
| `tester` | sonnet | Read, Grep, Glob, Bash, Write, Edit | Writes/runs tests; may not touch production source |

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

The model is passed as the Agent tool's per-dispatch `model` parameter (overrides agent frontmatter). Effort maps to an injected prompt banner — it is prompt-level guidance, not an API knob. Edit interactively with `/smithy:calibrate`, or one-shot: `/smithy:calibrate review=sonnet/medium`.

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
