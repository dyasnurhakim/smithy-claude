# Wield Playbook — Rust

## API (axum, actix-web, rocket, warp…)

- Prefer in-process QA where the framework supports it: axum's
  `tower::ServiceExt::oneshot`, actix's `actix_web::test` — the real router
  and extractors, no port juggling. Use a scratch integration file under
  `tests/` (e.g. `tests/qa_flows.rs`) — ask before committing it.
- Or run the real binary (`cargo run --release` for realistic behavior),
  poll until it is ready, and drive it with curl scripts.
- Per endpoint, test: the happy path; validation failures (check the 4xx
  code AND the shape of the error body); auth failures; not-found;
  malformed JSON; wrong content-type.
- Error responses must not leak internals (panic messages, file paths) —
  a leak is a High finding.
- Side effects: after a call that changes data, read it back and check it.

## CLI

- Drive the built binary from shell (or `assert_cmd` ONLY if it is already a
  dev-dependency): valid args, invalid args (usage on stderr + nonzero exit),
  `--help`, empty or huge stdin, invalid UTF-8 input where args/stdin allow
  it. Check exit codes, and that stdout and stderr stay separate.

## Console / log hygiene

- Capture stderr during flows. A worker panic (`thread '...' panicked`) that
  the framework turns into a 500 is still a Critical finding — a panic is
  not error handling.
