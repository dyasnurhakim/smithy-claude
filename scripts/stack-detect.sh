#!/usr/bin/env bash
# stack-detect.sh — sniff a project's stack from lockfiles/configs.
# Run from anywhere inside the project. Prints one line, e.g.:
#   stack=ts pkg=pnpm unit=vitest e2e=playwright
#   stack=python pkg=uv unit=pytest e2e=none
#   stack=go pkg=gomod unit=gotest e2e=none
#   stack=java pkg=maven unit=junit e2e=none
#   stack=rust pkg=cargo unit=cargotest e2e=none
#   stack=unknown pkg=none unit=none e2e=none
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

stack=unknown pkg=none unit=none e2e=none

# --- JS/TS ---
if [ -f package.json ]; then
  stack=js
  [ -f tsconfig.json ] && stack=ts
  if   [ -f pnpm-lock.yaml ];     then pkg=pnpm
  elif [ -f bun.lock ] || [ -f bun.lockb ]; then pkg=bun
  elif [ -f yarn.lock ];          then pkg=yarn
  elif [ -f package-lock.json ];  then pkg=npm
  else pkg=npm; fi
  # dep sniffing needs python3; without it, degrade gracefully to config-file
  # detection only (has_dep always false — never abort stack detection)
  has_dep() {
    command -v python3 >/dev/null 2>&1 || return 1
    python3 -c "
import json,sys
p=json.load(open('package.json'))
deps={**p.get('dependencies',{}),**p.get('devDependencies',{})}
sys.exit(0 if '$1' in deps else 1)" 2>/dev/null
  }
  if ls vitest.config.* >/dev/null 2>&1 || has_dep vitest; then unit=vitest
  elif ls jest.config.* >/dev/null 2>&1 || has_dep jest;   then unit=jest
  elif has_dep mocha; then unit=mocha; fi
  if ls playwright.config.* >/dev/null 2>&1 || has_dep '@playwright/test'; then e2e=playwright
  elif ls cypress.config.* >/dev/null 2>&1 || has_dep cypress; then e2e=cypress; fi
# --- Python ---
elif [ -f pyproject.toml ] || [ -f requirements.txt ] || [ -f setup.py ]; then
  stack=python
  if   [ -f uv.lock ];      then pkg=uv
  elif [ -f poetry.lock ];  then pkg=poetry
  elif [ -f Pipfile.lock ]; then pkg=pipenv
  else pkg=pip; fi
  if [ -f pytest.ini ] || grep -qs '\[tool\.pytest' pyproject.toml || grep -qs '^pytest' requirements*.txt 2>/dev/null; then
    unit=pytest
  elif [ -f pyproject.toml ] && grep -qs 'pytest' pyproject.toml; then unit=pytest; fi
# --- Go ---
elif [ -f go.mod ]; then
  stack=go; pkg=gomod; unit=gotest
# --- Java / JVM ---
elif [ -f pom.xml ]; then
  stack=java; pkg=maven; unit=junit
elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  # Kotlin/Groovy Gradle projects both route through the java playbooks
  stack=java; pkg=gradle; unit=junit
# --- Rust ---
elif [ -f Cargo.toml ]; then
  stack=rust; pkg=cargo; unit=cargotest
fi

# Multi-stack hint: list other detected manifests so callers know to confirm
# with the user instead of trusting first-match precedence blindly.
also=""
[ "$stack" != js ] && [ "$stack" != ts ] && [ -f package.json ] && also="$also,js"
[ "$stack" != python ] && { [ -f pyproject.toml ] || [ -f requirements.txt ]; } && also="$also,python"
[ "$stack" != go ]     && [ -f go.mod ]      && also="$also,go"
[ "$stack" != java ]   && { [ -f pom.xml ] || [ -f build.gradle ] || [ -f build.gradle.kts ]; } && also="$also,java"
[ "$stack" != rust ]   && [ -f Cargo.toml ]  && also="$also,rust"
also="${also#,}"

out="stack=$stack pkg=$pkg unit=$unit e2e=$e2e"
[ -n "$also" ] && out="$out also=$also"
echo "$out"
