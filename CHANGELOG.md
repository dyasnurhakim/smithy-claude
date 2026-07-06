# Changelog

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
