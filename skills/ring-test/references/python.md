# Ring-Test Playbook — Python

## Runner

pytest through the project's environment: `uv run pytest -q` (uv.lock),
`poetry run pytest -q` (poetry.lock), else `python3 -m pytest -q`.
Respect existing `pytest.ini` / `pyproject.toml [tool.pytest.ini_options]`.
Coverage (`--cov`) only if the project already configures it.

## Conventions

- Test location: match the existing pattern (usually `tests/test_*.py`).
- Structure: Arrange-Act-Assert; one behavior per test function.
- Names describe behavior: `test_returns_empty_list_when_no_items_match`.
- Fixtures over setup duplication; `parametrize` for input matrices.
- Mock at boundaries with `monkeypatch`/`unittest.mock.patch` targeting where
  the name is USED (not where it's defined). Never mock the unit under test.
- Exceptions asserted specifically: `pytest.raises(ValueError, match=...)`.
- No `xfail`/`skip` to get green; no broad `except` in tests.

## What to cover per behavior

1. Happy path with realistic input.
2. Edge: empty/None/boundary values, unicode where strings flow.
3. Error path: invalid input → documented failure mode, asserted specifically.

## Flakes

Rerun failures once: `pytest -q <nodeid>` — pass-on-rerun = FLAKY finding
(report; look for time, ordering, shared-state causes). Never add reruns
plugins to hide it.
