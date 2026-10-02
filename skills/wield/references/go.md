# Wield Playbook — Go

## API (net/http, chi, gin, echo…)

- Prefer **in-process QA** with `net/http/httptest`: start the real router
  inside a test binary and send it real HTTP requests — no port juggling,
  the real middleware stack. Put these in a scratch `qa_test.go` under the
  job's reports folder module, or in a `//go:build qa` tagged file. Never
  commit QA scaffolding into the production tree without asking.
- Or run the real binary (`go run ./cmd/...`), poll until it is ready, and
  drive it with `curl` / Go http client scripts.
- Per endpoint, test: the happy path; validation failures (check the 4xx code
  AND the shape of the error body); auth failures (401/403); not-found;
  malformed JSON; wrong content-type.
- Error responses must not leak internals (`runtime error`, file paths,
  SQL) — a leak is a High finding.
- Side effects: after a call that changes data, read it back and check it.

## CLI

- Drive it with `go run ./cmd/tool` or the built binary, from `os/exec`-style
  scripts or plain shell: valid args, invalid args (usage on stderr +
  nonzero exit), `--help`, empty or huge stdin. Check exit codes, and that
  stdout and stderr stay separate.

## Console / log hygiene

- Capture the service's stderr during flows. Middleware may recover from a
  panic but still print the stack trace — any panic trace during a QA flow
  is Critical.
