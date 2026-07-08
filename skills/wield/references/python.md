# Wield Playbook — Python

## API (FastAPI/Flask/Django)

- Prefer in-process test clients (httpx `ASGITransport`/`TestClient`,
  Flask `test_client`, Django `Client`) — no port juggling; else run the
  server via the project's own command and poll readiness.
- Per endpoint flow: happy path, validation failures (assert the 4xx code AND
  the error body shape), auth failures, not-found, malformed JSON, wrong
  content-type.
- Error responses must not leak tracebacks/internals — leak = High finding.
- Side-effect checks: after mutating calls, read back and assert state.

## CLI

- Invoke via `subprocess.run([...], capture_output=True, text=True)`:
  valid args, invalid args (usage on stderr + nonzero exit), `--help`,
  empty/huge stdin. Assert exit codes and stream separation.

## Web UI (rare for python-only repos)

- Use Playwright via `npx playwright` (ephemeral) against the running app;
  same flow rules as the TS playbook — including its MANDATORY screenshot
  evidence rule (per-flow, before/after mutations, per-finding, verified
  with `ls <evidence-dir>`).
