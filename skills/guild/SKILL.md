---
name: guild
description: Production-readiness review panel — parallel inspector agents with different personas (master engineer/security/QA/UIUX/SRE + patron end-user/product/marketing/support) judge the whole job and return one PRODUCTION_READY or NOT_READY verdict. Use when asked to "guild", "guild review", "production readiness review", "is this ready to ship", or automatically between forge and temper.
---

# Guild — Production-Readiness Panel

(A smith submits the masterpiece to the guild; the masters judge the craft,
the patrons judge whether it serves. Both must be satisfied.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/envelope.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append guild <slug> panel STARTED -`

This is smithy's most expensive operation (parallel opus reviewers). It runs
ONCE per job (end of FORGE, before TEMPER) or on explicit request — never
per task; per-task review stays with the solo `/smithy:inspect`.

## Checklist (create a todo per item)

1. Build the whole-job review package
2. Select personas by diff content; show the roster + cost note
3. Dispatch all selected personas IN PARALLEL (one message)
4. Synthesize: dedupe, verify, tag craft/experience
5. Single verdict written, ledger logged, findings routed

## 1. Build the package

Whole job, not one task: base = the job's base sha recorded at blueprint
(STATE.md). Standalone: ask the user for the base ref.
`bash ${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh build docs/smithy/jobs/<slug>/plan.md docs/smithy/jobs/<slug>/reports/guild-pkg.md`
(the plan stands in as the "brief" — the guild reviews against the whole
plan's success criteria plus the spec.)

## 2. Select the roster

Personas live at `${CLAUDE_PLUGIN_ROOT}/references/personas/`. Selection by
diff content (`git diff --stat <base>..HEAD` + file list):

| Persona | Fires when |
|---|---|
| masters/engineer.md | always |
| masters/security.md | always |
| masters/qa.md | diff touches behavior or tests (nearly always — skip only pure-docs diffs) |
| masters/uiux.md | frontend/UI files (.tsx/.vue/.svelte/.css/components/templates) |
| masters/sre.md | infra/config/deploy/perf paths (Dockerfile, k8s, terraform, .github, migrations, config) |
| patrons/end-user.md | any user-facing change (UI, API surface, CLI output, error messages) |
| patrons/product.md | any user-facing change |
| patrons/marketing.md | public surfaces (landing, README, onboarding, release notes, empty states) |
| patrons/support.md | error-handling, config, or user-data changes |

Show the selected roster with one-line reasons and note the cost (N parallel
`review`-routed agents). The user may trim or extend it. If
`docs/smithy/personas/` exists, tell patron-end-user's dispatch to read those
files too (its persona instructs it to embody them).

## 3. Dispatch — parallel, one message

Resolve routing ONCE: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh review`.
Dispatch ALL selected personas as `smithy:inspector` agents in a SINGLE
message (parallel Agent calls). Each prompt = effort banner + paths only:
persona file, guild package, creed, report output path
`docs/smithy/jobs/<slug>/reports/guild-<persona>.md` + the verbatim
Do-Not-Trust-the-Report line. Each returns only: verdicts, finding counts,
one-line summary.

## 4. Synthesize — you are the guildmaster

Read the report envelopes first (`envelope.sh get/list`), then bodies:

- **Dedupe** across personas by fingerprint `sha256(category+file+title)` —
  the same finding from two personas merges, keeping the higher severity and
  citing both personas.
- **Conflicts**: when personas disagree (security wants strictness, end-user
  wants fewer steps), present both positions with your recommendation —
  don't silently average.
- **Evaluate, don't obey** (inspect rules apply): verify generalizations
  against the diff; reclassify severities the finding's own text undercuts;
  findings below confidence 7 are labeled questions.
- Carry every unresolved `key_facts`/`concerns` envelope item into the
  verdict's envelope.

## 5. Verdict

Write `docs/smithy/jobs/<slug>/reports/guild-verdict.md` — envelope
(kind: guild-verdict, agent: controller, status: PRODUCTION_READY |
NOT_READY) + body:

```markdown
# Guild Verdict — <job>
## Verdict: PRODUCTION_READY | NOT_READY
Craft (masters): CLEAN | N findings   ·   Experience (patrons): CLEAN | N findings
## Roster
<persona — verdict — finding counts, one line each>
## Consolidated findings
| # | Tag | Severity | Confidence | Personas | Location | Finding |
## Conflicts & recommendations
## Deferred (user-accepted risks, if any)
```

PRODUCTION_READY requires BOTH tag groups free of Critical/High findings
(Medium/Low may ship with the user's explicit acceptance, recorded under
Deferred + decisions.md).

Log: `ledger.sh append guild <slug> panel <PASS|FAIL> reports/guild-verdict.md`
(PASS = PRODUCTION_READY). Route Critical/High fixes through `/smithy:forge`
(one brief per finding cluster), then re-run ONLY the personas that raised
them.

## Red flags

| Thought | Reality |
|---|---|
| "Nine personas would be more thorough" | Selection exists because parallel opus is real money. The roster matches the diff — respect it. |
| "Two personas found it, must be true" | Correlated reviewers share blind spots and hallucinations. Verify against the diff like any finding. |
| "Experience findings are subjective, downgrade them" | A user who can't complete the flow is as blocking as a null deref. The tag changes the fix owner, not the severity. |
| "It's NOT_READY but the findings are small, call it ready" | The verdict is computed from findings, not vibes. Fix them or get explicit user acceptance. |

Handoff: "PRODUCTION_READY → `/smithy:temper`. NOT_READY → `/smithy:forge` with the finding briefs."
