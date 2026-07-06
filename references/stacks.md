# Stack Detection & Tool Matrix

Shared by ring-test, wield, proof, hone, and temper. Detect first, confirm if
ambiguous, never guess.

## Detection

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh
→ stack=ts pkg=pnpm unit=vitest e2e=playwright
```

Detection sources: lockfiles (`pnpm-lock.yaml`, `bun.lock`, `yarn.lock`,
`package-lock.json`, `uv.lock`, `poetry.lock`, `Pipfile.lock`), configs
(`vitest.config.*`, `jest.config.*`, `playwright.config.*`, `cypress.config.*`,
`pytest.ini`, `pyproject.toml [tool.pytest]`), and `package.json` deps.

If `stack=unknown` or the result contradicts what you see in the repo, ask the
user — do not pick a toolchain silently.

## Tool matrix

| Purpose | TS/JS | Python | Fallback (any stack) |
|---|---|---|---|
| Unit tests (ring-test) | vitest / jest (as detected) | pytest | project's own test command from README/CI config; ask if none |
| QA / functional (wield) | Playwright (web UI), supertest/fetch (API) | pytest + httpx (API), Playwright via npx (web) | scripted CLI invocations |
| Stress / load (proof) | autocannon (default), k6 if installed | locust | ask user for tooling; a plain concurrent-curl loop only with documented caveats |
| Performance (hone) | `node --cpu-prof`, vitest bench | cProfile, pytest-benchmark | `time` + repeated runs, median of ≥3 |

## Runner invocations (canonical)

- vitest: `npx vitest run [--coverage]` — respect existing config
- jest: `npx jest [--coverage]`
- pytest: `python3 -m pytest -q [--cov]` (use the project's venv/uv if present:
  `uv run pytest`, `poetry run pytest`)
- playwright: `npx playwright test`
- autocannon: `npx autocannon -c <conns> -d <secs> <url>`
- locust: `locust --headless -u <users> -r <spawn-rate> -t <time> -H <host>`

## Rules

- Never install a tool into the user's project without asking. Prefer `npx`
  / `uv run` ephemeral execution when the tool is not a dependency.
- Respect existing configs; never create a competing config file when one
  exists.
- Tests must run through the project's own package manager scripts when they
  exist (`pnpm test`, `npm run test:unit`) — check `package.json` scripts /
  `Makefile` / CI workflow first.
