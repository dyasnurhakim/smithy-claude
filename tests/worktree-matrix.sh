#!/usr/bin/env bash
set -u
S=/home/dyasnurhakim/claude-agent/smithy/scripts
BASE_DIR="$(mktemp -d)"
trap 'rm -rf "$BASE_DIR"' EXIT
cd "$BASE_DIR" && mkdir repo && cd repo
git init -q -b main && git config user.email t@t.local && git config user.name T
mkdir -p docs/smithy && echo x > a.txt && git add -A && git commit -qm init
fails=0
ok(){ echo "PASS  $1"; }; bad(){ echo "FAIL! $1"; fails=$((fails+1)); }

echo "--- create two parallel worktrees ---"
P1=$(bash $S/worktree.sh create demo task-1 2>/dev/null) && [ -d "$P1" ] && ok "create task-1 → $P1" || bad "create task-1"
P2=$(bash $S/worktree.sh create demo task-2 2>/dev/null) && [ -d "$P2" ] && ok "create task-2" || bad "create task-2"
[ -f "$P1/.smithy-worktree" ] && ok "marker present" || bad "marker missing"

echo "--- guard inside worktree: grant resolves to MAIN root ---"
cd "$P1"
bash $S/guard.sh check "git commit -m x" >/dev/null 2>&1 && bad "commit allowed without grant in worktree" || ok "commit blocked without grant (worktree)"
cd "$BASE_DIR/repo" && bash $S/guard.sh grant demo >/dev/null
cd "$P1"
bash $S/guard.sh check "git commit -m x" >/dev/null 2>&1 && ok "commit allowed via MAIN-root grant (worktree)" || bad "grant not visible in worktree"

echo "--- disjoint work in both; integration stage ---"
echo one > "$P1/file1.txt" && git -C "$P1" add file1.txt && git -C "$P1" commit -qm "task-1: file1"
echo two > "$P2/file2.txt" && git -C "$P2" add file2.txt && git -C "$P2" commit -qm "task-2: file2"
cd "$BASE_DIR/repo"
INT=$(bash $S/worktree.sh integrate demo 2>/dev/null) && [ -d "$INT" ] && ok "integration worktree created" || bad "integrate"
bash $S/worktree.sh absorb demo task-1 >/dev/null 2>&1 && ok "absorb task-1 -> integration" || bad "absorb task-1"
bash $S/worktree.sh absorb demo task-2 >/dev/null 2>&1 && ok "absorb task-2 -> integration" || bad "absorb task-2"
[ -f "$INT/file1.txt" ] && [ -f "$INT/file2.txt" ] && ok "both files in integration" || bad "files missing in integration"
[ ! -f file1.txt ] && [ ! -f file2.txt ] && ok "working branch untouched before land" || bad "working branch polluted early"
bash $S/worktree.sh land demo >/dev/null 2>&1 && ok "land integration -> working branch" || bad "land"
[ -f file1.txt ] && [ -f file2.txt ] && ok "both files in main after land" || bad "files missing after land"

echo "--- review package against a branch ref ---"
echo brief > brief.md
# deterministic root commit (git log | tail -1 is timestamp-ordered, NOT topological)
printf '# Smithy State\n- Base sha: %s\n' "$(git rev-list --max-parents=0 HEAD)" > docs/smithy/STATE.md
bash $S/review-package.sh build brief.md pkg.md "" "smithy/demo/task-1" >/dev/null 2>&1 && grep -q 'task-1: file1' pkg.md && ok "package built from branch ref" || bad "branch-ref package"

echo "--- remove marked worktrees ---"
bash $S/worktree.sh remove "$P1" >/dev/null 2>&1 && [ ! -d "$P1" ] && ok "remove task-1 worktree" || bad "remove task-1"
bash $S/worktree.sh clean demo >/dev/null 2>&1 && [ ! -d "$P2" ] && [ ! -d "$INT" ] && ok "clean removes remaining incl. integration" || bad "clean"
git branch | grep -q 'smithy/demo' && bad "branches left behind" || ok "branches deleted after merge"

echo "--- USER worktree: refuse auto-removal ---"
git worktree add "$BASE_DIR/user-wt" -b user-branch >/dev/null 2>&1
bash $S/worktree.sh remove "$BASE_DIR/user-wt" >/dev/null 2>&1 && bad "removed a user worktree!" || ok "refused unmarked user worktree (ask instead)"

echo "--- conflict = non-disjoint batch detected ---"
P3=$(bash $S/worktree.sh create demo task-3 2>/dev/null)
echo main-edit >> a.txt && git add a.txt && git commit -qm "main: edit a"
echo wt-edit >> "$P3/a.txt" && git -C "$P3" add a.txt && git -C "$P3" commit -qm "task-3: edit a"
bash $S/worktree.sh absorb demo task-3 >/dev/null 2>&1 && bad "conflicting absorb succeeded?!" || ok "conflict aborted cleanly"
git status --porcelain | grep -q '^UU' && bad "merge left conflicts in tree" || ok "tree clean after aborted merge"

echo "=== FAILURES: $fails ==="
exit $fails
