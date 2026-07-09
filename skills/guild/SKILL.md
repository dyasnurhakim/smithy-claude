---
name: guild
description: "Production-readiness panel: parallel persona reviewers (masters=craft, patrons=experience) → one PRODUCTION_READY|NOT_READY verdict. Triggers: 'guild', 'ready to ship?'."
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
3. Live target for UI-facing personas (run app, evidence dir)
4. Dispatch all selected personas IN PARALLEL (one message)
5. Synthesize: dedupe, verify evidence, tag craft/experience
6. Verdict written (md + json), ledger logged, findings routed

## 1. Build the packages — scoped per persona family

Whole job, not one task: base = the job's base sha recorded at blueprint
(STATE.md). Standalone: ask the user for the base ref. Build the FULL
package plus SCOPED slices (a persona pays only for the diff it judges —
every slice keeps the plan and the complete changed-file list, so
cross-cutting context survives):

```
P=docs/smithy/jobs/<slug>; R=$P/reports
review-package.sh build $P/plan.md $R/guild-pkg.md          # full — engineer, security, qa, product
review-package.sh build $P/plan.md $R/guild-pkg-ui.md "" HEAD '*.tsx' '*.vue' '*.svelte' '*.css' '*.html' 'src/components/*' 'src/pages/*'   # uiux, designer, end-user, marketing
review-package.sh build $P/plan.md $R/guild-pkg-infra.md "" HEAD 'Dockerfile*' 'k8s/*' 'terraform/*' '.github/*' '*migrations*' '*.config.*' '*.env.example'   # sre, support
```

Adjust the pathspecs to the repo's real layout (check the file list first —
a slice that misses the repo's actual UI dir is worse than the full
package). A persona whose slice would be near-empty gets the full package
instead.

## 2. Select the roster

Personas live at `${CLAUDE_PLUGIN_ROOT}/references/personas/`. Selection by
diff content (`git diff --stat <base>..HEAD` + file list):

| Persona | Fires when |
|---|---|
| masters/engineer.md | always |
| masters/security.md | always |
| masters/qa.md | diff touches behavior or tests (nearly always — skip only pure-docs diffs) |
| masters/uiux.md | frontend/UI files (.tsx/.vue/.svelte/.css/components/templates) |
| masters/designer.md | frontend/UI/design-system files — judges identity & distinctiveness (uiux judges function; designer judges design) |
| masters/sre.md | infra/config/deploy/perf paths (Dockerfile, k8s, terraform, .github, migrations, config) |
| patrons/end-user.md | any user-facing change (UI, API surface, CLI output, error messages) |
| patrons/product.md | any user-facing change |
| patrons/marketing.md | public surfaces (landing, README, onboarding, release notes, empty states) |
| patrons/support.md | error-handling, config, or user-data changes |

Show the selected roster with one-line reasons and note the cost (N parallel
`review`-routed agents). The user may trim or extend it. If
`docs/smithy/personas/` exists, tell patron-end-user's dispatch to read those
files too (its persona instructs it to embody them).

## 3. Live evidence target (UI-facing personas)

When the diff is user-facing AND a runnable target exists (run command + URL
from spec.md/STATE.md — or ask; never guess a URL):

- Start the app (or confirm it's running) and poll readiness.
- The dispatch prompts for `masters/uiux`, `masters/designer`,
  `patrons/end-user`, `patrons/marketing`, and `patrons/support`
  additionally get: the target URL, and the evidence dir
  `docs/smithy/jobs/<slug>/reports/guild-evidence/<persona>/`.
- Those personas drive the target headlessly via Bash with Playwright
  (`npx playwright screenshot --viewport-size=1280,720 <url> <dir>/NNN-<what>.png`
  for states; a scratch spec file for multi-step flows — wield's ts playbook
  patterns apply) and MUST save a screenshot for every UI finding: the
  screenshot IS the proof.
- No runnable target, or Playwright unavailable → UI findings are capped at
  `cannot-verify` (confidence ≤4) and the verdict's Gaps section says why.
  LOCAL targets only — never drive a production URL without the user naming
  it this session.

## 4. Dispatch — parallel, one message

Resolve routing ONCE: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh review`.
Dispatch ALL selected personas as `smithy:inspector` agents in a SINGLE
message (parallel Agent calls). Each prompt = effort banner + paths only:
persona file, that persona's SCOPED package (full for engineer/security/
qa/product; ui slice for uiux/designer/end-user/marketing; infra slice for
sre/support), creed, report output path
`docs/smithy/jobs/<slug>/reports/guild-<persona>.md`, the live-target block
(step 3, when applicable) + the verbatim Do-Not-Trust-the-Report line.
Remind each: EVERY finding needs proof per the inspector evidence contract.
Each returns only: verdicts, finding counts, one-line summary.

## 5. Synthesize — you are the guildmaster

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

## 6. Verdict

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

**Also write the machine-readable twin** `reports/guild-verdict.json`
(consumers: CI, trend tooling, the next guild run's fingerprint dedupe):

```json
{
  "schema": 1,
  "job": "<slug>",
  "verdict": "PRODUCTION_READY|NOT_READY",
  "base": "<sha>", "head": "<sha>", "date": "<ISO>",
  "roster": [{"persona": "master-uiux", "verdict": "REJECTED", "findings": 3}],
  "findings": [{
    "id": 1,
    "fingerprint": "<sha256-12>",
    "personas": ["master-uiux", "patron-end-user"],
    "tag": "craft|experience",
    "severity": "Critical|High|Medium|Low",
    "severity_reason": "<why THIS severity — tie to the persona's calibration>",
    "confidence": 9,
    "location": {"file": "src/Form.tsx", "line": 42},
    "evidence": {
      "type": "screenshot|file|command",
      "path": "reports/guild-evidence/master-uiux/003-submit-no-feedback.png",
      "detail": "<what the evidence shows / verbatim output excerpt>"
    },
    "why": "<why this is a problem for this diff>",
    "fix": "<recommended action>",
    "status": "open|deferred"
  }]
}
```

Every finding in the JSON must have a non-empty `evidence` object,
`severity_reason`, and `why` — a finding you cannot evidence goes to the
Gaps section, not the findings list.

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
