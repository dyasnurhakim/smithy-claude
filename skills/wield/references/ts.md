# Wield Playbook — TypeScript/JavaScript

## Web UI (playwright detected or a web app is clear)

- Drive it with Playwright: `npx playwright test` against throwaway spec
  files in a scratch folder, or explore page by page if an MCP browser is
  available.
- Start the app with the project's own dev/start script; wait until it is
  ready (poll the URL) — never sleep and hope.
- Per flow: navigate → act → check the VISIBLE result (text / state), not
  just HTTP 200. Capture console errors (`page.on('console')`) — any
  error-level console message is at least a Medium finding.
- Edge variants: empty inputs, very long strings, special characters,
  double submits, the back button after submit.
- **Screenshots are required, not only on failure** (evidence rule):
  `await page.screenshot({ path: '<evidence-dir>/NNN-<flow>-<state>.png' })`
  at every flow's check point, BEFORE and AFTER every action that changes
  data, and one per finding (`issue-NNN-<what>.png`). Use the evidence
  folder from the brief. In a scratch spec, screenshots are just lines in
  the test — write them in from the start, not added after something fails.
- Check the files exist before reporting: put the `ls <evidence-dir>` output
  in the report word for word. Zero PNGs on a UI run = your report is invalid.

## API (no UI, or supertest/fetch fits)

- Call endpoints with `fetch` / supertest scripts: happy path, validation
  failures (check each 400 exactly), auth failures (401/403), not-found
  (404), malformed bodies.
- Check the response SHAPE (fields, types), not just status codes.
- Error responses must not leak stack traces or internals — a leak = High.

## CLI

- Script the calls: valid args, invalid args (usage + nonzero exit), empty
  stdin, `--help`. Check that stdout and stderr stay separate, and the exit codes.
