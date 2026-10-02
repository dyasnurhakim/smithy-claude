#!/usr/bin/env bash
# tdd-snap.sh — proof that tests came first, without extra commits.
#
#   tdd-snap.sh start  <job> <task>                     save the "before" picture
#   tdd-snap.sh take   <job> <task> RED|GREEN|REFACTOR [note]
#                                                       save a picture after a stage
#   tdd-snap.sh verify <job> <task> [--audit]           check the pictures, print one line
#
# The idea, in one picture:
#
#   start ──▶ RED ──────────▶ GREEN ─────────▶ (REFACTOR) ──▶ one normal commit
#   (before)  tests added,    code added,       tidy up         "feat: ..."
#             they fail       tests pass
#
# Each "picture" is a git TREE object: the full content of the working folder
# at that moment. We build it with a throw-away index file, so:
#   - HEAD, branches, the real index and your files are never touched;
#   - no commit is made, so `git log` stays clean (one commit per task);
#   - the trees are loose objects; git cleans them up later on its own.
#
# The log (one line per picture, written by THIS script at the moment the
# stage ends) lives at:  $SMITHY_MEM/jobs/<job>/reports/raw/<task>-tdd.log
#
# verify checks:
#   1. the order is right: RED (one or more), then GREEN, then optional
#      REFACTOR — repeated per cycle;
#   2. every RED adds a test (a test file, or a test line like `def test_`);
#   3. every GREEN changes at least one non-test file (the real code);
#   4. nothing changed after the last picture (no unrecorded edits).
#      Skipped with --audit: later tasks change files on purpose, so a review
#      at the END of a job re-checks only the order (1-3). Run plain verify
#      right after each task; it writes its verdict into the log.
# It also WARNS (does not fail) when a test written at RED is edited at GREEN,
# because that is how a test gets quietly weakened.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./paths.sh
. "$SCRIPT_DIR/paths.sh"

die() { echo "tdd-snap.sh: $*" >&2; exit 2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repo"
ROOT="$(cd "$ROOT" && pwd -P)"   # real path, so the memory check below works through symlinks

# Paths that count as tests. Matches the common layouts of the five stacks
# smithy supports (ts/js, python, go, java/kotlin, rust) plus ruby/elixir.
TEST_PATH_RE='(^|/)(tests?|__tests__|specs?|testing)/|(^|/)test_[^/]*\.py$|_test\.(py|go|rb|exs?)$|\.(test|spec)\.[cm]?[jt]sx?$|Tests?\.(java|kt|cs)$|(^|/)src/test/|_spec\.rb$|(^|/)conftest\.py$'
# Added lines that count as tests even inside a normal source file
# (Rust keeps unit tests next to the code, for example).
TEST_LINE_RE='^\+.*(#\[test\]|#\[cfg\(test\)\]|def test_|func Test|@Test\b|\b(it|test|describe)\()'

# If the memory folder is inside the repo, keep it out of every picture:
# the log file itself changes on each `take` and must not look like code.
EXCLUDE=()
MEM_REAL="$SMITHY_MEM"
[ -d "$SMITHY_MEM" ] && MEM_REAL="$(cd "$SMITHY_MEM" && pwd -P)"
case "$MEM_REAL/" in
  "$ROOT"/*) rel="${MEM_REAL#"$ROOT"/}"; EXCLUDE=(":(exclude)$rel") ;;
esac

# Job and unit names become parts of a file path, so they must be one plain
# segment: letters, digits, dot, dash, underscore — and never "..".
check_name() {
  case "$1" in ''|*..*|.*) die "bad name '$1' (use letters, digits, . - _ ; no '..')" ;; esac
  printf '%s' "$1" | grep -qE '^[A-Za-z0-9._-]+$' || die "bad name '$1' (use letters, digits, . - _ ; no '..')"
}
log_path() { check_name "$1"; check_name "$2"; echo "$SMITHY_MEM/jobs/$1/reports/raw/$2-tdd.log"; }

# snap — print the tree id of the working folder right now.
snap() {
  local idx real
  idx="$(mktemp)"
  real="$(git -C "$ROOT" rev-parse --git-path index)"
  case "$real" in /*) ;; *) real="$ROOT/$real" ;; esac
  # Start from a copy of the real index so unchanged files are not re-read.
  if [ -f "$real" ]; then cp "$real" "$idx"; else rm -f "$idx"; fi
  (
    cd "$ROOT"
    GIT_INDEX_FILE="$idx" git add -A -- . "${EXCLUDE[@]}" >/dev/null 2>&1
    GIT_INDEX_FILE="$idx" git write-tree
  )
  rm -f "$idx"
}

# core.quotePath=false: print non-ASCII names as they are (not "caf\303\251"),
# so the test-path pattern can match them.
changed() { # changed <tree-a> <tree-b> [diff-filter] — file names that differ
  git -C "$ROOT" -c core.quotePath=false diff --name-only ${3:+--diff-filter=$3} "$1" "$2" -- . "${EXCLUDE[@]}"
}

cmd="${1:-}"
case "$cmd" in
  start)
    [ $# -eq 3 ] || die "usage: tdd-snap.sh start <job> <task>"
    log="$(log_path "$2" "$3")"
    mkdir -p "$(dirname "$log")"
    tree="$(snap)"
    # A new start replaces an old log: a re-run task proves its order again.
    printf '# base %s\n' "$tree" > "$log"
    echo "start: base=${tree:0:12} log=$log"
    ;;

  take)
    [ $# -ge 4 ] || die "usage: tdd-snap.sh take <job> <task> RED|GREEN|REFACTOR [note]"
    stage="$4"; note="${5:-}"
    note="${note//[$'\n\r|']/ }"   # one line, no "|": the log is one line per picture
    case "$stage" in RED|GREEN|REFACTOR) ;; *) die "stage must be RED, GREEN or REFACTOR (got '$stage')" ;; esac
    log="$(log_path "$2" "$3")"
    [ -f "$log" ] || die "no log yet — run 'tdd-snap.sh start $2 $3' before the first test"
    # The tree to compare with: the base line, or the last picture taken.
    prev="$(grep -v '^# verify' "$log" | tail -n 1 | awk '/^# base / {print $3; next} {split($0, f, / [|] /); print f[3]}')"
    tree="$(snap)"
    n="$(changed "$prev" "$tree" | grep -c . || true)"
    printf '%s | %s | %s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$stage" "$tree" "$n" "$note" >> "$log"
    echo "take: $stage tree=${tree:0:12} files-changed=$n"
    ;;

  verify)
    [ $# -eq 3 ] || [ $# -eq 4 ] || die "usage: tdd-snap.sh verify <job> <task> [--audit]"
    audit=0
    if [ $# -eq 4 ]; then [ "$4" = "--audit" ] || die "unknown option '$4'"; audit=1; fi
    log="$(log_path "$2" "$3")"
    [ -f "$log" ] || { echo "tdd-verify: FAIL no log at $log (start/take were never run)"; exit 1; }
    base="$(awk '/^# base / {print $3; exit}' "$log")"
    [ -n "$base" ] || { echo "tdd-verify: FAIL log has no '# base' line"; exit 1; }

    fail() {
      echo "tdd-verify: FAIL $*"
      [ "$audit" -eq 1 ] || printf '# verify FAIL %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$log"
      exit 1
    }
    warns=()
    prev="$base"; last_stage="START"; red_tests=""
    cycles=0; reds=0; greens=0; refactors=0
    while IFS='|' read -r ts stage tree _ _; do
      ts=" $(echo "$ts" | tr -d ' ')"; stage="$(echo "$stage" | tr -d ' ')"; tree="$(echo "$tree" | tr -d ' ')"
      files="$(changed "$prev" "$tree")"
      case "$stage" in
        RED)
          # A RED may follow any stage: a new cycle starts after GREEN/REFACTOR.
          # Only ADDED or MODIFIED test files count; deleting a test is not a RED.
          tests="$(changed "$prev" "$tree" AM | grep -E "$TEST_PATH_RE" || true)"
          if [ -z "$tests" ] && ! git -C "$ROOT" -c core.quotePath=false diff "$prev" "$tree" -- . "${EXCLUDE[@]}" | grep -qE "$TEST_LINE_RE"; then
            fail "RED at$ts adds no test (changed: $(echo "$files" | tr '\n' ' '))"
          fi
          # Only warn when tests live in their own files; inline tests (Rust)
          # share a file with the code, so a non-test path is expected there.
          other="$(echo "$files" | grep -vE "$TEST_PATH_RE" | grep . || true)"
          [ -z "$tests" ] || [ -z "$other" ] || warns+=("RED at$ts also changed non-test files: $(echo "$other" | tr '\n' ' ')(a stub is fine; real logic is not)")
          # A RED after GREEN/REFACTOR starts a new cycle: forget the old cycle's tests.
          case "$last_stage" in GREEN|REFACTOR) red_tests="" ;; esac
          red_tests="$red_tests"$'\n'"$tests"
          reds=$((reds + 1))
          ;;
        GREEN)
          case "$last_stage" in
            RED) ;;
            # A second GREEN = more code after the full suite found a break.
            # Fine, but it adds code without a new failing test, so flag it.
            GREEN) warns+=("GREEN at$ts follows another GREEN — code added without a new failing test; check it only fixes breakage") ;;
            *) fail "GREEN at$ts has no RED right before it (last stage: $last_stage)" ;;
          esac
          code="$(echo "$files" | grep -vE "$TEST_PATH_RE" | grep . || true)"
          [ -n "$files" ] || fail "GREEN at$ts changed nothing"
          [ -n "$code" ] || fail "GREEN at$ts changed only test files — no code was written"
          touched="$(printf '%s\n' "$files" | grep -Fxf <(printf '%s\n' "$red_tests" | grep .) || true)"
          [ -z "$touched" ] || warns+=("test written at RED was edited at GREEN: $(echo "$touched" | tr '\n' ' ')— check it was not weakened")
          greens=$((greens + 1))
          [ "$last_stage" = "RED" ] && cycles=$((cycles + 1))
          ;;
        REFACTOR)
          case "$last_stage" in GREEN|REFACTOR) ;; *) fail "REFACTOR at$ts must come after GREEN (last stage: $last_stage)" ;; esac
          refactors=$((refactors + 1))
          ;;
        *) fail "unknown stage '$stage' in log" ;;
      esac
      prev="$tree"; last_stage="$stage"
    done < <(grep -v '^#' "$log" | grep .)

    [ "$reds" -gt 0 ] || fail "no RED picture (tests were never shown to fail first)"
    [ "$greens" -gt 0 ] || fail "no GREEN picture (code was never shown to pass)"
    [ "$last_stage" != "RED" ] || fail "the last stage is RED — a RED was never made GREEN"

    if [ "$audit" -eq 0 ]; then
      now="$(snap)"
      late="$(changed "$prev" "$now")"
      [ -z "$late" ] || fail "files changed after the last picture: $(echo "$late" | tr '\n' ' ')(take a picture, or explain the edit)"
    fi

    result="OK cycles=$cycles red=$reds green=$greens refactor=$refactors warnings=${#warns[@]}"
    [ "$audit" -eq 1 ] && result="$result (audit: order only)"
    echo "tdd-verify: $result"
    [ "$audit" -eq 1 ] || printf '# verify %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$result" >> "$log"
    for w in "${warns[@]+"${warns[@]}"}"; do echo "WARN: $w"; done
    ;;

  ""|-h|--help)
    sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    [ -n "$cmd" ] || exit 2 ;;
  *)
    die "unknown command '$cmd' (try --help)" ;;
esac
