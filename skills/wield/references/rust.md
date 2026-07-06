# Wield Playbook — Rust

## API (axum, actix-web, rocket, warp…)

- Prefer in-process QA where the framework supports it: axum's
  `tower::ServiceExt::oneshot`, actix's `actix_web::test` — real router and
  extractors, no port juggling. Scratch integration file under `tests/`
  (e.g. `tests/qa_flows.rs`) — ask before committing it.
- Else run the real binary (`cargo run --release` for realistic behavior),
  poll readiness, drive with curl scripts.
- Per endpoint flow: happy path; validation failures (assert the 4xx code AND
  the error body shape); auth failures; not-found; malformed JSON; wrong
  content-type.
- Error responses must not leak internals (panic messages, file paths) —
  leak = High finding.
- Side-effect checks: after mutating calls, read back and assert state.

## CLI

- Drive the built binary via shell (or `assert_cmd` ONLY if it's already a
  dev-dependency): valid args, invalid args (usage on stderr + nonzero exit),
  `--help`, empty/huge stdin, invalid UTF-8 input where args/stdin allow it.
  Assert exit codes and stdout/stderr separation.

## Console/log hygiene

- Capture stderr during flows. A worker panic (`thread '...' panicked`) that
  the framework recovers into a 500 is still a Critical finding — panics are
  not error handling.
