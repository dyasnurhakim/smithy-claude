# Changelog

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
