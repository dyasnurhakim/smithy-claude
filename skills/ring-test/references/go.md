# Ring-Test Playbook — Go

## Runner

`go test ./...` from the module root; one package with `go test ./pkg/name`.
Coverage only if the project already tracks it: `go test ./... -cover`.
Check the Makefile / CI workflow first — many Go repos set their flags there.

## Conventions

- Test file next to the source: `foo.go` → `foo_test.go`, same package (or
  `package foo_test` for black-box tests — match what the repo uses).
- **Table-driven tests** are the Go way: a slice of named cases, one behavior
  per case, `t.Run(tc.name, ...)` subtests.
- Names: `TestFuncName_scenario` (e.g. `TestSlugify_emptyInput`).
- Check errors directly: `errors.Is` / `errors.As` for sentinel or wrapped
  errors. Do not match on error text unless the text IS the contract.
- Use `t.Helper()` in test helpers; `t.Cleanup()` instead of manual defers.
- Mock only at interfaces the code already defines. Do not bring in a
  mocking framework the repo does not use (hand-written fakes are normal in Go).
- No `testify` unless it is already in go.mod.

## What to cover per behavior

1. Happy path with realistic input.
2. Edges: zero values, nil slices/maps, empty strings, boundary numbers.
3. Error path: bad input → the documented error, checked with `errors.Is`.

## Flakes

Rerun a failure with the cache off: `go test -count=1 -run 'TestName' ./pkg`.
Passes on the rerun = a FLAKY finding. If you suspect a concurrency problem,
run `go test -race` once and report the result — a race hit is a Critical
finding, not a flake.
