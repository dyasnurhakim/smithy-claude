# Changelog

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
