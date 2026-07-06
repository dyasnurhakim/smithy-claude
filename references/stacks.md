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
`pytest.ini`, `pyproject.toml [tool.pytest]`), `package.json` deps, and build
manifests (`go.mod`, `pom.xml`, `build.gradle[.kts]`, `Cargo.toml`).

If `stack=unknown` or the result contradicts what you see in the repo, ask the
user — do not pick a toolchain silently.

An `also=` field (e.g. `stack=js ... also=go`) means MULTIPLE manifests were
found — a mixed repo. Ask the user which stack the current job targets; never
assume first-match precedence got it right.

## Tool matrix

| Purpose | TS/JS | Python | Go | Java | Rust | Fallback (any stack) |
|---|---|---|---|---|---|---|
| Unit tests (ring-test) | vitest / jest | pytest | `go test` | JUnit via mvn/gradle | `cargo test` | project's own test command from README/CI; ask if none |
| QA / functional (wield) | Playwright (UI), supertest/fetch (API) | pytest + httpx (API) | `httptest` (in-process), `net/http` client | MockMvc/TestRestTemplate (Spring) or HttpClient | axum/actix test utils, `std::process` for CLI | scripted CLI invocations; Playwright via npx for any web UI |
| Stress / load (proof) | autocannon, k6 if installed | locust | autocannon via npx (any HTTP target) — or hey/vegeta/wrk/k6 if installed | same | same | ask; concurrent-curl loop only with documented caveats |
| Performance (hone) | `node --cpu-prof`, vitest bench | cProfile, pytest-benchmark | `go test -bench` + pprof | JMH if configured, else JFR (`jcmd`) | criterion via `cargo bench` (else `--release` + hyperfine/time) | `time` + repeated runs, median of ≥3 |

Load tools are client-side: autocannon/k6 stress ANY http service regardless
of its implementation language — only the monitoring hooks differ per stack.

## Runner invocations (canonical)

- vitest: `npx vitest run [--coverage]` — respect existing config
- jest: `npx jest [--coverage]`
- pytest: `python3 -m pytest -q [--cov]` (use the project's venv/uv if present:
  `uv run pytest`, `poetry run pytest`)
- go: `go test ./... [-cover]`; single package `go test ./pkg/name`; flake
  recheck with `-count=1` (defeats the test cache)
- maven: `mvn -q test`; single class `mvn -q test -Dtest=ClassName`
- gradle: `./gradlew test` (wrapper first; bare `gradle` only if no wrapper);
  single class `./gradlew test --tests 'ClassName'`
- cargo: `cargo test [--workspace]`; single test `cargo test name_substring`
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
