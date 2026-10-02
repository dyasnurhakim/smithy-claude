# Ring-Test Playbook — TypeScript/JavaScript

## Runner

Use the detected runner (vitest or jest) through the project's own scripts
when they exist: check `package.json` scripts first (`test`, `test:unit`).
Otherwise: `npx vitest run` / `npx jest`. Coverage: `--coverage` only if the
project already has coverage config; do not add thresholds nobody asked for.

## Conventions

- Test file location: match the existing pattern (`*.test.ts` next to the
  source, or `__tests__/`, or `tests/`) — grep for existing tests first.
- Structure: Arrange-Act-Assert, one behavior per `test()` / `it()`.
- Names say the behavior: `test('returns empty array when no items match')`,
  not `test('works')`.
- Mock at module boundaries (`vi.mock` / `jest.mock`); never mock the unit
  under test. Prefer fakes over deep mock chains.
- Async: always `await`; no floating promises; use fake timers for time logic.
- Do not add `--force`, `--passWithNoTests` or skip annotations to get green.

## What to cover per behavior

1. Happy path with realistic input.
2. Edges: empty / null / undefined / boundary values.
3. Error path: bad input → the documented failure (thrown error, error
   result), checked exactly (`toThrow(SpecificError)`).

## Flakes

Rerun a failure once: `npx vitest run <file>`. Passes on the rerun = a FLAKY
finding (report it; look at timers, network, test order). Never `retry: N`.
