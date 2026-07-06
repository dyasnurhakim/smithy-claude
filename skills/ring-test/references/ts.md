# Ring-Test Playbook — TypeScript/JavaScript

## Runner

Use the detected runner (vitest or jest) through the project's own scripts
when they exist: check `package.json` scripts first (`test`, `test:unit`).
Otherwise: `npx vitest run` / `npx jest`. Coverage: `--coverage` only if the
project already has coverage config; don't introduce thresholds uninvited.

## Conventions

- Test file location: match the existing pattern (`*.test.ts` next to source,
  or `__tests__/`, or `tests/`) — grep for existing tests before choosing.
- Structure: Arrange-Act-Assert, one behavior per `test()`/`it()`.
- Names describe behavior: `test('returns empty array when no items match')`,
  not `test('works')`.
- Mock at module boundaries (`vi.mock` / `jest.mock`); never mock the unit
  under test. Prefer fakes over deep mock chains.
- Async: always `await`; no floating promises; use fake timers for time logic.
- Do not add `--force`, `--passWithNoTests`, or skip annotations to get green.

## What to cover per behavior

1. Happy path with realistic input.
2. Edge: empty/null/undefined/boundary values.
3. Error path: invalid input → the documented failure mode (thrown error,
   error result), asserted specifically (`toThrow(SpecificError)`).

## Flakes

Rerun failures once: `npx vitest run <file>` — pass-on-rerun = FLAKY finding
(report it; investigate timers/network/order dependence). Never `retry: N`.
