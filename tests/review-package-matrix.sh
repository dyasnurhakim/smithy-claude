#!/usr/bin/env bash
# review-package.sh test matrix. Run: bash tests/review-package-matrix.sh
set -u
P="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/review-package.sh"
R="$(mktemp -d)"
trap 'cd /; rm -rf "$R"' EXIT
cd "$R" || exit 1
git init -q -b main && git config user.email t@t && git config user.name t
export SMITHY_MEM_DIR="$R/mem"
mkdir -p "$SMITHY_MEM_DIR"
echo one > a.txt && git add . && git commit -qm "c1" && B="$(git rev-parse HEAD)"
echo two >> a.txt && git commit -qam "c2"
echo three >> a.txt && git commit -qam "c3"
echo dirty >> a.txt                       # uncommitted change
echo "# brief" > brief.md
fails=0
t() { if [ "$2" = "$3" ]; then printf 'PASS  %s\n' "$1"; else printf 'FAIL! %s (want %s, got %s)\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi; }

bash "$P" build --base "$B" brief.md out.md >/dev/null
t "--base: both commits after base are listed" 2 "$(sed -n '/^## Commits/,/^## Changed/p' out.md | grep -c '^[0-9a-f]\{7,\} c[23]')"
t "--base: uncommitted change NOT in HEAD diff" 0 "$(grep -c '^+dirty' out.md)"
t "--base: STATE.md is never written" no "$([ -f "$SMITHY_MEM_DIR/STATE.md" ] && echo yes || echo no)"

bash "$P" build --base "$B" brief.md wt.md - WORKTREE >/dev/null
t "WORKTREE: uncommitted change IS in the diff" 1 "$(grep -c '^+dirty' wt.md)"
t "WORKTREE: head label says so" 1 "$(grep -c '^Head: working tree' wt.md)"

bash "$P" build brief.md none.md >/dev/null 2>&1
t "no --base and no STATE base: refused" 1 "$?"

bash "$P" record-base >/dev/null
bash "$P" build brief.md st.md >/dev/null
t "STATE base (= HEAD) gives an empty commit list" 0 "$(sed -n '/^## Commits/,/^## Changed/p' st.md | grep -c '^[0-9a-f]\{7,\} ')"

bash "$P" build --base nope brief.md bad.md >/dev/null 2>&1
t "a base that is not a commit is refused" 1 "$?"
bash "$P" build --base "$B" brief.md bad.md - no-such-branch >/dev/null 2>&1
t "a target that is not a commit is refused" 1 "$?"

echo newfile > brand_new.py                 # untracked, never added
bash "$P" build --base "$B" brief.md wt2.md "" WORKTREE >/dev/null
t "WORKTREE: untracked new file IS in the diff" 1 "$(grep -c '^+++ b/brand_new.py' wt2.md)"
t "WORKTREE: the real index is untouched" "" "$(git diff --cached --name-only)"

bash "$P" build brief.md late.md --base "$B" >/dev/null 2>&1
t "--base after the paths is refused (not silently ignored)" 2 "$?"

mkdir -p rep && echo "# r1" > rep/task-1-impl.md && echo "# r2" > rep/task-2-impl.md
bash "$P" build --base "$B" brief.md folder.md rep >/dev/null
t "a reports folder lists every report in it" 2 "$(grep -c '^- rep/task-[12]-impl.md' folder.md)"

# Two jobs at once: a lane's record-base must not overwrite the project's base.
proj_base="$(git rev-parse HEAD~1)"
printf -- '- Base sha: %s\n' "$proj_base" > "$SMITHY_MEM_DIR/STATE.md"
mkdir -p "$SMITHY_MEM_DIR/lanes/job-b"
printf -- '- Base sha: none\n' > "$SMITHY_MEM_DIR/lanes/job-b/STATE.md"
SMITHY_LANE=job-b bash "$P" build brief.md lanefb.md >/dev/null
t "a lane with no base falls back to the project base" 1 "$(grep -c "^Base: $proj_base" lanefb.md)"
SMITHY_LANE=job-b bash "$P" record-base >/dev/null
t "record-base in a lane leaves the project base alone" "$proj_base" "$(grep -m1 '^- Base sha:' "$SMITHY_MEM_DIR/STATE.md" | awk '{print $4}')"
t "…and writes the lane's own base" "$(git rev-parse HEAD)" "$(grep -m1 '^- Base sha:' "$SMITHY_MEM_DIR/lanes/job-b/STATE.md" | awk '{print $4}')"

echo
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
