# Ring-Test Playbook — Rust

## Runner

`cargo test` (add `--workspace` in a workspace). One test:
`cargo test name_substring`. Doc tests run on their own — do not turn them off.
Coverage only if the repo already uses a tool (`cargo llvm-cov`, tarpaulin).

## Conventions

- Unit tests in the same file: `#[cfg(test)] mod tests { use super::*; ... }` —
  they may test private items.
- Integration tests in `tests/` (public API only). Match where the repo
  already puts things.
- Names: `#[test] fn returns_empty_vec_when_no_items_match()`.
- Assertions: `assert_eq!` / `assert!`, with a message when the values alone
  will not explain the failure.
- Error paths: check the variant, not the Debug string —
  `assert!(matches!(result, Err(MyError::InvalidInput { .. })))`.
  `#[should_panic(expected = "...")]` only when a panic IS the contract.
- Tests that return `Result<(), E>` are fine when the setup uses `?` a lot.
- No new dev-dependencies (proptest, rstest, mockall) unless already in
  Cargo.toml — hand-written fakes behind traits are normal in Rust.

## What to cover per behavior

1. Happy path with realistic input.
2. Edges: empty collections, `None`, boundary numbers (incl. near overflow),
   non-ASCII strings where `&str` passes through.
3. Error path: bad input → the documented `Err` variant, matched exactly.

## Flakes

Rerun the failing test alone: `cargo test name -- --exact`. Passes on the
rerun = a FLAKY finding. Usual causes: shared temp files, port clashes,
thread timing. Use `--test-threads=1` to confirm an order dependence, then
FIX the test — do not ship the flag.
