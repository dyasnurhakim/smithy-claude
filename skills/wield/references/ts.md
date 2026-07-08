# Wield Playbook — TypeScript/JavaScript

## Web UI (playwright detected or web app evident)

- Drive with Playwright: `npx playwright test` against ephemeral spec files
  in a scratch dir, or page-driven exploration if an MCP browser is available.
- Start the app with the project's own dev/start script; wait for readiness
  (poll the URL), never sleep-and-hope.
- Per flow: navigate → act → assert VISIBLE outcome (text/state), not just
  HTTP 200. Capture console errors (`page.on('console')`) — any error-level
  console message is at least a Medium finding.
- Edge variants: empty inputs, over-long strings, special characters, double
  submits, back-button after submit.
- **Screenshots are mandatory, not on-failure-only** (evidence contract):
  `await page.screenshot({ path: '<evidence-dir>/NNN-<flow>-<state>.png' })`
  at every flow's assertion point, BEFORE and AFTER every mutating action,
  and one per finding (`issue-NNN-<what>.png`). Use the evidence dir from
  the brief. In a scratch spec, screenshots are just lines in the test —
  write them in from the start, not retrofitted after something fails.
- Verify files landed before reporting: `ls <evidence-dir>` output goes in
  the report verbatim. Zero PNGs on a UI run = your report is invalid.

## API (no UI, or supertest/fetch appropriate)

- Exercise endpoints with `fetch`/supertest scripts: happy path, validation
  failures (400s asserted specifically), auth failures (401/403), not-found
  (404), malformed bodies.
- Assert response SHAPE (fields, types), not just status codes.
- Error responses must not leak stack traces or internals — leak = High.

## CLI

- Script invocations: valid args, invalid args (usage + nonzero exit),
  empty stdin, `--help`. Assert stderr/stdout separation and exit codes.
