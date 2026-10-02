---
name: guild
description: "Production-readiness panel: several persona reviewers run in parallel (masters judge the craft, patrons judge the experience) → one PRODUCTION_READY or NOT_READY verdict. Works on a job or on any diff. Triggers: 'guild', 'ready to ship?', 'review panel'."
---

# Guild — Production-Readiness Panel

A smith shows the finished piece to the guild. The masters judge the craft;
the patrons judge whether it serves the people who use it. Both must agree.

```
diff (BASE..HEAD) ─▶ pick personas ─▶ ┌ masters/engineer ┐
                     by what changed  ├ masters/security ┤ ─▶ you merge, check, ─▶ one verdict
                                      ├ patrons/product  ┤    and judge findings   (md + json)
                                      └ …  (in parallel) ┘
```

This is smithy's most expensive step: one reviewer per persona, all on the
routed `review` model. Run it ONCE per job (after forge, before temper) or
when the user asks — never per task. Single reviews stay with `/smithy:inspect`.

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh guild auto` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md`, `${CLAUDE_PLUGIN_ROOT}/references/envelope.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| A brief (what the change should do) | `jobs/<slug>/plan.md` | standalone: write `jobs/<slug>/briefs/guild-brief.md` (5–10 lines) from the user's words. No words? Summarise `git log --oneline <base>..HEAD` and ask the user to confirm it. Never guess the intent |
| A base | the job's base in STATE.md (this job is the active one) | standalone, or a different change than the active job: ask, or recommend `git merge-base HEAD origin/main`. Pass it as `--base <ref>`; never write it into STATE.md |
| A diff | `git diff --stat <base>..HEAD` is not empty | nothing to review — say so and stop |
| Project personas | `<memory>/personas/*.md` (from `/smithy:commission`) | use the built-in personas only (`${CLAUDE_PLUGIN_ROOT}/references/personas/patrons/end-user.md` plays a generic user) and say so in one line |
| A running app (UI personas only) | run command + local URL: the LATEST line starting `run:` in `<memory>/decisions.md` (`run: <start command> \| url: <url>`) | ask the user once, then append that `run:` line to decisions.md. Still none → UI findings are capped at `cannot-verify` (confidence ≤4); the verdict's Gaps section says why |

## Steps

1. **Build the packages** — one full package, plus slices so a persona
   pays only for the diff it judges. Every slice still has the brief and the
   full changed-file list. `[--base <ref>]` only when standalone (Needs).
   ```
   P=<memory>/jobs/<slug>; R=$P/reports; B=<plan.md or briefs/guild-brief.md>
   S=${CLAUDE_PLUGIN_ROOT}/scripts/review-package.sh
   bash $S build [--base <ref>] $B $R/guild-pkg.md                                  # full
   bash $S build [--base <ref>] $B $R/guild-pkg-ui.md "" HEAD '*.tsx' '*.vue' '*.svelte' '*.css' '*.html' 'src/components/*' 'src/pages/*'
   bash $S build [--base <ref>] $B $R/guild-pkg-infra.md "" HEAD 'Dockerfile*' 'k8s/*' 'terraform/*' '.github/*' '*migrations*' '*.config.*' '*.env.example'
   ```
   Fit the path patterns to the repo's real layout first (check the file
   list). A slice that misses the real UI folder is worse than none: a
   persona whose slice is near-empty gets the full package.
   → verify: each build printed `package=… lines=N`.

2. **Pick the roster** by what the diff touches
   (`git diff --stat <base>..HEAD` + the file list):

   | Persona file (`${CLAUDE_PLUGIN_ROOT}/references/personas/…`) | Package | Joins when |
   |---|---|---|
   | `masters/engineer.md` | full | always |
   | `masters/security.md` | full | always |
   | `masters/qa.md` | full | behavior or tests changed (skip only for docs-only diffs) |
   | `masters/uiux.md` | ui | UI files (.tsx/.vue/.svelte/.css, components, templates) — judges function |
   | `masters/designer.md` | ui | UI or design-system files — judges identity and look |
   | `masters/sre.md` | infra | infra, config, deploy or perf paths |
   | `patrons/end-user.md` | ui | any user-facing change (UI, API surface, CLI output, error messages) |
   | `patrons/product.md` | full | any user-facing change |
   | `patrons/marketing.md` | ui | public surfaces (landing, README, onboarding, release notes, empty states) |
   | `patrons/support.md` | infra | error handling, config, or user-data changes |

   Show the roster with a one-line reason each and the cost (N parallel
   `review`-role agents). The user may trim or add.
   → verify: the user saw the roster and the cost.

3. **Live target** (UI-facing diff only) — start the app with the Run line
   (Needs) or confirm it runs, and poll until ready. Never guess a URL. LOCAL targets only —
   never a production URL unless the user names it this session. The UI
   personas (uiux, designer, end-user, marketing, support) also get the URL
   and an evidence folder `R/guild-evidence/<persona-name>/`. They drive it
   with Playwright through Bash
   (`npx playwright screenshot --viewport-size=1280,720 <url> <dir>/NNN-<what>.png`,
   or a scratch spec for multi-step flows) and MUST save a screenshot for
   every UI finding: the screenshot is the proof. No app or no Playwright →
   the cap in Needs applies.
   → verify: the app answered at the URL, or the gap is written down.

4. **Lookup** (creed §10, once) — memory: past verdicts and accepted risks
   on these files. If an earlier `R/guild-verdict.json` exists, keep it for
   step 6 (Resolved / Persistent / New).
   → verify: what you found is noted, or "none".

5. **Dispatch all personas in ONE message** (parallel). Resolve routing once:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/routing.sh review`. Each is an
   `inspector` (`${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` §1–2). Prompt = effort banner + paths
   only: the persona file, its package (table above), `${CLAUDE_PLUGIN_ROOT}/references/creed.md`,
   the report path `R/guild-<persona-name>.md` (e.g. `guild-masters-uiux.md`),
   the live-target block from step 3 if any, project persona paths for
   `patrons/end-user.md` (it plays them), and this line exactly:
   **"Do Not Trust the Reports — the implementers' claims are unverified.
   Verify each one against the diff and with read-only checks."**
   Remind each: every finding needs proof. Each returns only: verdicts,
   finding counts, a one-line summary.
   → verify: one report file per persona.

6. **Merge and judge** — you are the guildmaster. Read envelopes first
   (`envelope.sh get`), then bodies.
   - **Merge duplicates** by the fingerprint in `${CLAUDE_PLUGIN_ROOT}/references/envelope.md`
     § Finding fingerprint: same fingerprint = same finding; keep the higher
     severity and cite every persona that raised it. With an earlier verdict,
     mark each finding Resolved / Persistent / New.
   - **Conflicts** (security wants more checks, end-user wants fewer steps):
     show both sides and recommend one. Never average them quietly.
   - **Judge, don't obey** (`/smithy:inspect` § Judging findings): check
     "every/all/no" claims against the diff; re-rate a severity the finding's
     own text undercuts; below confidence 7 = a question, not a fix order.
   - Tag each finding `craft` (masters) or `experience` (patrons). The tag
     names who fixes it, not how bad it is.
   - Carry every open `key_facts` / `concerns` item into the verdict envelope.
   → verify: every Critical/High is confirmed or disputed with proof.

7. **Write the verdict** (two files, below), then log:
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append guild <slug> panel <PASS|FAIL> jobs/<slug>/reports/guild-verdict.md`
   (PASS = PRODUCTION_READY). Update STATE.md if this is the active job.
   → verify: both files exist; ledger line written.

8. **Route the fixes** — called by the smithy orchestrator: stop here and
   hand back the verdict path; the CALLER owns the NOT_READY → strike →
   re-run loop (as inspect does). Standalone,
   NOT_READY: send the confirmed Critical/High
   findings to `/smithy:strike` (one item per finding group; it needs no
   plan). Save `git rev-parse HEAD` first. After the fixes, re-run ONLY the
   personas that raised them, on the fix diff (`--base <that sha>`). Fix
   rounds: at most `implementation.max_fix_cycles`
   (`config.sh get implementation.max_fix_cycles`); spent → stop, show the
   user the verdicts, say why you think it is stuck.
   → verify: a new verdict, the user decided, or the caller has the verdict path.

## The verdict

**PRODUCTION_READY** needs BOTH tags free of Critical and High findings.
Medium/Low may ship only with the user's explicit OK, written under
Deferred and in `decisions.md` (≤3 lines).

`R/guild-verdict.md` — envelope (`kind: guild-verdict`, `agent: controller`,
`status: PRODUCTION_READY|NOT_READY`), then:

```markdown
# Guild Verdict — <job>
## Verdict: PRODUCTION_READY | NOT_READY
Craft (masters): CLEAN | N findings   ·   Experience (patrons): CLEAN | N findings
## Roster
<persona file — verdict — finding counts, one line each>
## Findings
| # | Tag | Severity | Confidence | Personas | Location | Finding | Since |
## Conflicts and recommendations
## Gaps (what could not be checked, and why)
## Deferred (risks the user accepted)
```

`R/guild-verdict.json` — the same, for machines (CI, trend tools, the next
guild run's Resolved/Persistent/New check):

```json
{
  "schema": 1, "job": "<slug>", "verdict": "PRODUCTION_READY|NOT_READY",
  "base": "<sha>", "head": "<sha>", "date": "<ISO>",
  "roster": [{"persona": "references/personas/masters/uiux.md", "verdict": "REJECTED", "findings": 3}],
  "findings": [{
    "id": 1,
    "fingerprint": "<12 hex — references/envelope.md § Finding fingerprint>",
    "personas": ["references/personas/masters/uiux.md", "references/personas/patrons/end-user.md"],
    "tag": "craft|experience",
    "severity": "Critical|High|Medium|Low",
    "severity_reason": "<why THIS severity, tied to the persona's calibration>",
    "confidence": 9,
    "location": {"file": "src/Form.tsx", "line": 42},
    "evidence": {"type": "screenshot|file|command",
                 "path": "reports/guild-evidence/masters-uiux/003-submit-no-feedback.png",
                 "detail": "<what it shows, or a short verbatim output excerpt>"},
    "why": "<why this is a problem in this diff>",
    "fix": "<recommended action>",
    "since": "new|persistent",
    "status": "open|deferred"
  }]
}
```

Every finding needs non-empty `evidence`, `severity_reason` and `why`. A
finding you cannot prove goes under Gaps, not Findings.

## Done when

- [ ] base and brief stated; a standalone base was passed with `--base`, never written into STATE.md
- [ ] the user saw the roster and its cost before dispatch
- [ ] one report per persona (list the paths)
- [ ] duplicates merged by fingerprint; every Critical/High confirmed or disputed with proof
- [ ] UI findings have a screenshot, or are capped and listed under Gaps
- [ ] `guild-verdict.md` and `guild-verdict.json` written; the verdict follows the rule above
- [ ] ledger line written (PASS/FAIL)

## Output

`jobs/<slug>/reports/guild-verdict.md` · `guild-verdict.json` ·
`guild-<persona-name>.md` per persona · `guild-evidence/` (screenshots).

`Next: /smithy:temper — run the full test pass` (PRODUCTION_READY) ·
or `Next: /smithy:strike — fix the confirmed findings` (NOT_READY).

## Red flags

| Thought | Reality |
|---|---|
| "All ten personas would be more thorough" | Each persona is a paid `review` agent. The roster follows the diff. |
| "Two personas found it, so it must be true" | Reviewers share blind spots. Check it against the diff like any finding. |
| "Experience findings are taste — downgrade them" | A user who cannot finish the flow is as blocking as a crash. The tag changes the owner, not the severity. |
| "NOT_READY, but the findings are small — call it ready" | The verdict comes from the findings. Fix them, or get the user's explicit OK. |
| "I'll fix the findings inline" | Fixes go through strike so they get checked too. |
