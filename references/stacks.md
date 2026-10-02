# Stack Detection & Tool Matrix

Used by ring-test, wield, proof, hone and temper. Detect first. If the
result is unclear, confirm with the user. Never guess.

## Detection

```
bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh
→ stack=ts pkg=pnpm unit=vitest e2e=playwright
```

What it looks at: lockfiles (`pnpm-lock.yaml`, `bun.lock`, `yarn.lock`,
`package-lock.json`, `uv.lock`, `poetry.lock`, `Pipfile.lock`), configs
(`vitest.config.*`, `jest.config.*`, `playwright.config.*`, `cypress.config.*`,
`pytest.ini`, `pyproject.toml [tool.pytest]`), `package.json` deps, and build
manifests (`go.mod`, `pom.xml`, `build.gradle[.kts]`, `Cargo.toml`).

`stack=unknown`, or a result that does not match what you see in the repo →
ask the user. Do not pick a toolchain quietly.

An `also=` field (e.g. `stack=js ... also=go`) means it found MORE than one
manifest — a mixed repo. Ask the user which stack this job is about; do not
trust that the first match is right.

## Tool matrix

| Purpose | TS/JS | Python | Go | Java | Rust | Fallback (any stack) |
|---|---|---|---|---|---|---|
| Unit tests (ring-test) | vitest / jest | pytest | `go test` | JUnit via mvn/gradle | `cargo test` | the project's own test command from README/CI; ask if none |
| QA / functional (wield) | Playwright (UI), supertest/fetch (API) | pytest + httpx (API) | `httptest` (in-process), `net/http` client | MockMvc/TestRestTemplate (Spring) or HttpClient | axum/actix test utils, `std::process` for CLI | scripted CLI calls; Playwright via npx for any web UI |
| Stress / load (proof) | autocannon, k6 if installed | locust | autocannon via npx (any HTTP target) — or hey/vegeta/wrk/k6 if installed | same | same | ask; a loop of parallel curls only, with its limits written down |
| Performance (hone) | `node --cpu-prof`, vitest bench | cProfile, pytest-benchmark | `go test -bench` + pprof | JMH if set up, else JFR (`jcmd`) | criterion via `cargo bench` (else `--release` + hyperfine/time) | `time` + repeated runs, median of ≥3 |

Load tools run on the client side: autocannon or k6 can stress ANY HTTP
service, whatever language it is written in. Only the monitoring (what you
watch on the server) differs per stack.

## Runner commands (standard)

- vitest: `npx vitest run [--coverage]` — respect the existing config
- jest: `npx jest [--coverage]`
- pytest: `python3 -m pytest -q [--cov]` (use the project's env if present:
  `uv run pytest`, `poetry run pytest`)
- go: `go test ./... [-cover]`; one package `go test ./pkg/name`; to recheck
  a flaky test use `-count=1` (skips the test cache)
- maven: `mvn -q test`; one class `mvn -q test -Dtest=ClassName`
- gradle: `./gradlew test` (the wrapper first; plain `gradle` only if there
  is no wrapper); one class `./gradlew test --tests 'ClassName'`
- cargo: `cargo test [--workspace]`; one test `cargo test name_substring`
- playwright: `npx playwright test`
- autocannon: `npx autocannon -c <conns> -d <secs> <url>`
- locust: `locust --headless -u <users> -r <spawn-rate> -t <time> -H <host>`

## Rules

- Never install a tool into the user's project without asking. When the
  tool is not a dependency, prefer a one-off run (`npx`, `uv run`).
- Respect existing configs. Never add a second config file when one exists.
- Run tests through the project's own scripts when they exist (`pnpm test`,
  `npm run test:unit`) — check `package.json` scripts, the `Makefile` and
  the CI workflow first.
