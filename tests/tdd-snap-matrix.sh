#!/usr/bin/env bash
# tdd-snap.sh test matrix. Run: bash tests/tdd-snap-matrix.sh
# Each case builds a fresh scratch repo, plays a TDD story, and checks the
# verdict. "OK"/"FAIL" is what `verify` must print; WARN cases also check
# that a warning line appears.
set -u
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/tdd-snap.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
fails=0
pass() { printf 'PASS  %s\n' "$1"; }
bad()  { printf 'FAIL! %s\n' "$1"; fails=$((fails + 1)); }

# new_repo <name> [mem-inside-repo] — fresh repo with one commit; sets R and mem dir
new_repo() {
  R="$SCRATCH/$1"; mkdir -p "$R" && cd "$R" || exit 1
  git init -q -b main
  git config user.email t@t; git config user.name t
  echo "x" > README.md && git add . && git commit -qm init
  if [ "${2:-}" = inside ]; then export SMITHY_MEM_DIR="$R/docs/smithy"
  else export SMITHY_MEM_DIR="$SCRATCH/mem-$1"; fi
  mkdir -p "$SMITHY_MEM_DIR"
}
snap()   { bash "$S" "$@" >/dev/null 2>&1; }
verdict() { bash "$S" verify j t1 2>&1; }
expect() { # expect <OK|FAIL> <name> [warn-substring]
  out="$(verdict)"
  case "$out" in
    "tdd-verify: $1"*) ;;
    *) bad "$2 — want $1, got: $(echo "$out" | head -1)"; return ;;
  esac
  if [ -n "${3:-}" ] && ! echo "$out" | grep -q "WARN: .*$3"; then
    bad "$2 — want a WARN containing '$3', got: $out"; return
  fi
  pass "$2"
}

echo "--- happy paths ---"
new_repo happy
head0="$(git rev-parse HEAD)"; refs0="$(git for-each-ref | wc -l)"
snap start j t1
mkdir -p src tests
echo "test add" > tests/test_add.py
bash "$S" take j t1 RED "2 tests fail: add missing" 2>&1 | grep -q "files-changed=1" && pass "take counts files changed since the base" || bad "take miscounted files changed since the base"
echo "def add(): pass" > src/add.py;  snap take j t1 GREEN "2 passed"
[ "$(git rev-parse HEAD)" = "$head0" ] && pass "take never moves HEAD" || bad "take moved HEAD"
[ -z "$(git diff --cached --name-only)" ] && pass "take never touches the real index" || bad "take staged files in the real index"
[ "$(git for-each-ref | wc -l)" = "$refs0" ] && pass "take creates no refs" || bad "take created refs"
expect OK "batched RED then GREEN, not committed yet"
git add -A && git commit -qm "feat: add"
expect OK "same story after the one task commit"
[ "$(git rev-list --count HEAD)" = 2 ] && pass "history is init + ONE task commit" || bad "unexpected commit count"

new_repo cycles
snap start j t1
mkdir -p tests src
echo a > tests/a.test.ts; snap take j t1 RED
echo a > src/a.ts;        snap take j t1 GREEN
echo b > tests/b.test.ts; snap take j t1 RED
echo b > src/b.ts;        snap take j t1 GREEN
echo c >> src/b.ts;       snap take j t1 REFACTOR
out="$(verdict)"; echo "$out" | grep -q 'cycles=2' && pass "two RED/GREEN cycles + REFACTOR (max level)" || bad "cycles: $out"

new_repo rust
snap start j t1
mkdir -p src
printf 'fn f(){}\n#[cfg(test)]\nmod t { #[test] fn x(){} }\n' > src/lib.rs; snap take j t1 RED
printf 'fn f(){ 1; }\n#[cfg(test)]\nmod t { #[test] fn x(){} }\n' > src/lib.rs; snap take j t1 GREEN
expect OK "inline test lines count as a test (Rust style)"
verdict | grep -q "warnings=0" && pass "inline tests raise no stub warning" || bad "inline tests raised a stub warning"

new_repo dirty
echo "unrelated" > notes.txt     # untracked file that was there before the task
snap start j t1
mkdir -p tests src
echo t > tests/x_test.go; snap take j t1 RED
echo s > src/x.go;        snap take j t1 GREEN
expect OK "a file that existed before start is not counted"

new_repo memin inside
snap start j t1
mkdir -p tests src
echo t > tests/test_m.py; snap take j t1 RED
echo s > src/m.py;        snap take j t1 GREEN
expect OK "memory dir inside the repo is left out of pictures"

new_repo audit
snap start j t1
mkdir -p tests src
echo t > tests/test_a.py; snap take j t1 RED
echo s > src/a.py;        snap take j t1 GREEN
verdict >/dev/null
grep -q '^# verify .* OK ' "$SMITHY_MEM_DIR/jobs/j/reports/raw/t1-tdd.log" && pass "verify writes its verdict into the log" || bad "verify did not log its verdict"
echo later > src/b.py      # a LATER task changes more files
out="$(bash "$S" verify j t1 --audit 2>&1)"
case "$out" in "tdd-verify: OK"*"audit"*) pass "--audit ignores later tasks' changes" ;; *) bad "--audit: $out" ;; esac
case "$(verdict)" in "tdd-verify: FAIL"*) pass "plain verify still catches them" ;; *) bad "plain verify missed later changes" ;; esac
echo t2 > tests/test_b.py; snap take j t1 RED
echo s2 > src/b2.py;      snap take j t1 GREEN
rm src/b.py; snap take j t1 REFACTOR
expect OK "take after a logged verdict still compares with the last picture"

new_repo greengreen
snap start j t1
mkdir -p tests src
echo t > tests/test_a.py; snap take j t1 RED
echo s > src/a.py;        snap take j t1 GREEN
echo fix > src/other.py;  snap take j t1 GREEN "full suite found a break"
expect OK "GREEN right after GREEN (fixing a break) passes" "follows another GREEN"
verdict | grep -q 'cycles=1' && pass "a second GREEN is not a new cycle" || bad "second GREEN counted as a cycle"

echo "--- cheats and mistakes that must FAIL ---"
new_repo nored
snap start j t1
echo s > app.py; snap take j t1 RED
expect FAIL "RED with no test in it"

new_repo greenfirst
snap start j t1
echo s > app.py; snap take j t1 GREEN
expect FAIL "GREEN with no RED before it (code first)"

new_repo onlytests
snap start j t1
mkdir -p tests
echo t > tests/test_a.py; snap take j t1 RED
echo t2 > tests/test_b.py; snap take j t1 GREEN
expect FAIL "GREEN that only adds tests (no code)"

new_repo late
snap start j t1
mkdir -p tests src
echo t > tests/test_a.py; snap take j t1 RED
echo s > src/a.py;        snap take j t1 GREEN
echo more >> src/a.py      # edit after the last picture
expect FAIL "edit after the last picture"

new_repo endred
snap start j t1
mkdir -p tests src
echo t > tests/test_a.py; snap take j t1 RED
echo s > src/a.py;        snap take j t1 GREEN
echo t > tests/test_b.py; snap take j t1 RED
expect FAIL "story ends on RED"

new_repo nolog
expect FAIL "no log at all"

echo "--- warnings (pass, but flagged) ---"
new_repo weaken
snap start j t1
mkdir -p tests src
echo "assert 2" > tests/test_a.py; snap take j t1 RED
echo s > src/a.py; echo "assert 1" > tests/test_a.py; snap take j t1 GREEN
expect OK "test edited at GREEN" "was edited at GREEN"

new_repo stub
snap start j t1
mkdir -p tests src
echo t > tests/test_a.py; echo "def a(): raise" > src/a.py; snap take j t1 RED
echo "def a(): return 1" > src/a.py; snap take j t1 GREEN
expect OK "RED with a stub file" "non-test files"

echo "--- edge cases found in review ---"
new_repo multiline
snap start j t1
mkdir -p tests src
echo t > tests/test_a.py; bash "$S" take j t1 RED $'1 failed\nE  assert 1 == 2 | x' >/dev/null 2>&1
echo s > src/a.py
bash "$S" take j t1 GREEN 2>&1 | grep -q "files-changed=1" && pass "a multi-line note does not break the log" || bad "multi-line note broke the next take"
expect OK "…and verify still works after it"

new_repo unicode
snap start j t1
mkdir -p tests src
echo t > "tests/test_café.py"; snap take j t1 RED
echo s > "src/données.py";     snap take j t1 GREEN
expect OK "non-ASCII test and code paths are classified correctly"

new_repo unicodecheat
snap start j t1
mkdir -p tests
echo t > tests/test_a.py;      snap take j t1 RED
echo t2 > "tests/données.py";  snap take j t1 GREEN
expect FAIL "a non-ASCII TEST file is not mistaken for code at GREEN"

new_repo deleted
mkdir -p tests && echo old > tests/test_old.py && git add -A && git commit -qm old
snap start j t1
rm tests/test_old.py;     snap take j t1 RED
expect FAIL "deleting a test is not a RED"

new_repo escape
bash "$S" start j '../../../../escaped' >/dev/null 2>&1; t_rc=$?
[ "$t_rc" -eq 2 ] && [ ! -e "$SCRATCH/escaped-tdd.log" ] && pass "'..' in a name is refused (nothing written outside memory)" || bad "path escape not refused (rc=$t_rc)"
bash "$S" start 'a b' t1 >/dev/null 2>&1; [ $? -eq 2 ] && pass "a space in a job name is refused" || bad "space in job name accepted"

new_repo symlinked
real="$R"; link="$SCRATCH/link-to-symlinked"; ln -s "$real" "$link"; cd "$link" || exit 1
export SMITHY_MEM_DIR="$link/docs/smithy"; mkdir -p "$SMITHY_MEM_DIR"
snap start j t1
mkdir -p tests src
echo t > tests/test_a.py; snap take j t1 RED
echo s > src/a.py;        snap take j t1 GREEN
expect OK "memory inside a repo reached through a symlink is still left out"

echo "--- usage errors ---"
new_repo usage
bash "$S" take j t1 RED >/dev/null 2>&1; [ $? -eq 2 ] && pass "take before start is refused" || bad "take before start was accepted"
bash "$S" start j >/dev/null 2>&1;       [ $? -eq 2 ] && pass "start with missing args is refused" || bad "start with missing args was accepted"
snap start j t1
bash "$S" take j t1 BLUE >/dev/null 2>&1; [ $? -eq 2 ] && pass "unknown stage is refused" || bad "unknown stage was accepted"

echo
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
