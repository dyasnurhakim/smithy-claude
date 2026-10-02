# Wield Playbook — Python

## API (FastAPI/Flask/Django)

- Prefer in-process test clients (httpx `ASGITransport` / `TestClient`,
  Flask `test_client`, Django `Client`) — no port juggling. Otherwise run the
  server with the project's own command and poll until it is ready.
- Per endpoint, test: the happy path, validation failures (check the 4xx
  code AND the shape of the error body), auth failures, not-found, malformed
  JSON, wrong content-type.
- Error responses must not leak tracebacks or internals — a leak is a High finding.
- Side effects: after a call that changes data, read it back and check it.

## CLI

- Call it with `subprocess.run([...], capture_output=True, text=True)`:
  valid args, invalid args (usage on stderr + nonzero exit), `--help`,
  empty or huge stdin. Check exit codes, and that stdout and stderr stay separate.

## Web UI (rare in Python-only repos)

- Use Playwright via `npx playwright` (one-off run) against the running app;
  same flow rules as the TS playbook — including its REQUIRED screenshot
  rule (per flow, before/after changes, per finding, checked with
  `ls <evidence-dir>`).
