# Ring-Test Playbook — Python

## Runner

pytest through the project's environment: `uv run pytest -q` (uv.lock),
`poetry run pytest -q` (poetry.lock), else `python3 -m pytest -q`.
Respect an existing `pytest.ini` / `pyproject.toml [tool.pytest.ini_options]`.
Coverage (`--cov`) only if the project already sets it up.

## Conventions

- Test location: match the existing pattern (usually `tests/test_*.py`).
- Structure: Arrange-Act-Assert; one behavior per test function.
- Names say the behavior: `test_returns_empty_list_when_no_items_match`.
- Fixtures instead of repeated setup; `parametrize` for input tables.
- Mock at boundaries with `monkeypatch` / `unittest.mock.patch`, aimed at
  where the name is USED (not where it is defined). Never mock the unit
  under test.
- Check exceptions by type: `pytest.raises(ValueError, match=...)`.
- No `xfail` / `skip` to get green; no broad `except` in tests.

## What to cover per behavior

1. Happy path with realistic input.
2. Edges: empty / None / boundary values, unicode where strings pass through.
3. Error path: bad input → the documented failure, checked by type.

## Flakes

Rerun a failure once: `pytest -q <nodeid>`. Passes on the rerun = a FLAKY
finding (report it; look for time, ordering or shared-state causes). Never
add rerun plugins to hide it.
