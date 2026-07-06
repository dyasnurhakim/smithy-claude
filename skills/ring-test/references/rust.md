# Ring-Test Playbook — Rust

## Runner

`cargo test` (add `--workspace` in a workspace). Single test:
`cargo test name_substring`. Doc tests run automatically — don't disable them.
Coverage only if the repo already uses a tool (`cargo llvm-cov`, tarpaulin).

## Conventions

- Unit tests in-file: `#[cfg(test)] mod tests { use super::*; ... }` —
  they may exercise private items.
- Integration tests in `tests/` (public API only). Match where the repo
  already puts things.
- Names: `#[test] fn returns_empty_vec_when_no_items_match()`.
- Assertions: `assert_eq!`/`assert!` with a failure message where the values
  alone won't explain the failure.
- Error paths: assert the variant, not the Debug string —
  `assert!(matches!(result, Err(MyError::InvalidInput { .. })))`.
  `#[should_panic(expected = "...")]` only for genuine panic contracts.
- `Result<(), E>`-returning tests are fine for `?`-heavy arrange steps.
- No new dev-dependencies (proptest, rstest, mockall) unless already in
  Cargo.toml — hand-rolled fakes over trait objects are idiomatic.

## What to cover per behavior

1. Happy path with realistic input.
2. Edge: empty collections, `None`, boundary numerics (incl. overflow-adjacent),
   non-ASCII strings where `&str` flows.
3. Error path: invalid input → the documented `Err` variant, matched specifically.

## Flakes

Rerun the failing test alone: `cargo test name -- --exact`. Pass-on-rerun =
FLAKY finding — usual suspects: shared temp files, port collisions, thread
timing (`--test-threads=1` to confirm order dependence, then FIX the test,
don't ship the flag).
