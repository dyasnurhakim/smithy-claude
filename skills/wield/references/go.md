# Wield Playbook — Go

## API (net/http, chi, gin, echo…)

- Prefer **in-process QA** with `net/http/httptest`: spin the real router in
  a test binary, drive it with real HTTP requests — no port juggling, real
  middleware stack. Put these in a scratch `qa_test.go` under the job's
  reports dir module or a `//go:build qa` tagged file — never commit QA
  scaffolding into the production tree without asking.
- Alternatively run the real binary (`go run ./cmd/...`), poll readiness,
  drive with `curl`/Go http client scripts.
- Per endpoint flow: happy path; validation failures (assert the 4xx code AND
  the error body shape); auth failures (401/403); not-found; malformed JSON;
  wrong content-type.
- Error responses must not leak internals (`runtime error`, file paths,
  SQL) — leak = High finding.
- Side-effect checks: after mutating calls, read back and assert state.

## CLI

- Drive via `go run ./cmd/tool` or the built binary with `os/exec`-style
  scripts or plain shell: valid args, invalid args (usage on stderr +
  nonzero exit), `--help`, empty/huge stdin. Assert exit codes and
  stdout/stderr separation.

## Console/log hygiene

- Capture the service's stderr during flows; panics recovered by middleware
  still print stack traces — any panic trace during a QA flow is Critical.
