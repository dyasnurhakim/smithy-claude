# Ring-Test Playbook — Go

## Runner

`go test ./...` from the module root; a single package with `go test ./pkg/name`.
Coverage only if the project already tracks it: `go test ./... -cover`.
Check the Makefile / CI workflow first — many Go repos wrap flags there.

## Conventions

- Test file next to source: `foo.go` → `foo_test.go`, same package (or
  `package foo_test` for black-box tests — match whichever the repo uses).
- **Table-driven tests** are the idiom: a slice of named cases, one behavior
  per case, `t.Run(tc.name, ...)` subtests.
- Names: `TestFuncName_scenario` (e.g. `TestSlugify_emptyInput`).
- Errors asserted explicitly: `errors.Is`/`errors.As` for sentinel/wrapped
  errors — never string-match error messages unless the message IS the contract.
- Use `t.Helper()` in test helpers; `t.Cleanup()` over manual defers.
- Mock at interface boundaries the code already defines; do not introduce a
  mocking framework the repo doesn't use (hand-rolled fakes are idiomatic).
- No `testify` unless it's already in go.mod.

## What to cover per behavior

1. Happy path with realistic input.
2. Edge: zero values, nil slices/maps, empty strings, boundary numbers.
3. Error path: invalid input → the documented error, asserted with `errors.Is`.

## Flakes

Rerun failures with the cache defeated: `go test -count=1 -run 'TestName' ./pkg`.
Pass-on-rerun = FLAKY finding. For concurrency suspicion, run `go test -race`
once and report the outcome — a race hit is a Critical finding, not a flake.
