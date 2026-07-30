#!/usr/bin/env bash
set -u
# Self-contained lane.sh / ledger.sh lane matrix. Run: bash tests/lane-matrix.sh
# Covers lane resolution, state isolation, the merge union, and the worktree wiring.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
BASE="$(mktemp -d)"; trap 'rm -rf "$BASE"' EXIT
fails=0

t() { # t <desc> <expect> <actual>
  if [ "$3" = "$2" ]; then printf 'PASS  %-46s %s\n' "$1" "$3"
  else printf 'FAIL! %-46s want=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails+1)); fi
}
tc() { # tc <desc> <expect-substr> <actual>
  case "$3" in *"$2"*) printf 'PASS  %-46s %s\n' "$1" "$2" ;;
  *) printf 'FAIL! %-46s want~%s got=%s\n' "$1" "$2" "$3"; fails=$((fails+1)) ;; esac
}
lane_of()  { bash "$SCRIPTS/paths.sh" lane; }
statedir() { bash "$SCRIPTS/paths.sh" state-dir; }

# Mutates the caller's cwd/env on purpose — must NOT be command-substituted.
new_repo() { # new_repo <name>
  R="$BASE/$1"
  mkdir -p "$R" && cd "$R" && git init -q -b main
  git config user.email t@t.local && git config user.name T
  export SMITHY_HOME="$BASE/$1-home"
  mkdir -p "$SMITHY_HOME" "$R/docs/smithy"
  unset SMITHY_MEM_DIR SMITHY_LANE
  echo x > "$R/f.txt" && git add -A && git commit -qm init
  MEM="$R/docs/smithy"
}

echo "--- resolution: no lane is the default ---"
new_repo r1
t  "no lane resolves to empty"          ""      "$(lane_of)"
t  "state dir is the project mem dir"   "$MEM"  "$(statedir)"
bash "$SCRIPTS/ledger.sh" append forge demo task-1 DONE r1.md
t  "append lands in the project ledger" "1"     "$(wc -l < "$MEM/ledger.md" | tr -d ' ')"

echo "--- resolution: env var and marker ---"
t  "env lane sets the state dir"        "$MEM/lanes/a" "$(SMITHY_LANE=a bash "$SCRIPTS/paths.sh" state-dir)"
t  "env lane names itself"              "a"     "$(SMITHY_LANE=a bash "$SCRIPTS/paths.sh" lane)"
printf 'marker-lane\n' > "$R/.smithy-lane"
t  "marker resolves when env is unset"  "marker-lane" "$(lane_of)"
t  "env beats the marker"               "env-lane"    "$(SMITHY_LANE=env-lane bash "$SCRIPTS/paths.sh" lane)"
rm -f "$R/.smithy-lane"

echo "--- resolution: an unsafe lane name is ignored, never sanitised ---"
for bad in "../escape" "a/b" ".hidden" 'a;rm' "with space"; do
  t  "rejects '$bad'"                   ""      "$(SMITHY_LANE="$bad" bash "$SCRIPTS/paths.sh" lane)"
  t  "...falls back to the shared dir"  "$MEM"  "$(SMITHY_LANE="$bad" bash "$SCRIPTS/paths.sh" state-dir)"
done
tc "and says why"  "ignoring invalid lane name" \
   "$(SMITHY_LANE=../escape bash "$SCRIPTS/paths.sh" --dump | grep lane_warning)"

echo "--- isolation: concurrent lanes never see each other ---"
new_repo r2
bash "$SCRIPTS/ledger.sh" append forge demo task-1 DONE base.md
bash "$SCRIPTS/lane.sh" start la --job demo >/dev/null
bash "$SCRIPTS/lane.sh" start lb --job demo >/dev/null
SMITHY_LANE=la bash "$SCRIPTS/ledger.sh" append forge demo task-2 DONE a.md
SMITHY_LANE=la bash "$SCRIPTS/ledger.sh" append inspect demo task-2 APPROVED a2.md
SMITHY_LANE=lb bash "$SCRIPTS/ledger.sh" append forge demo task-3 DONE b.md
t  "project ledger untouched by lanes"  "1" "$(wc -l < "$MEM/ledger.md" | tr -d ' ')"
t  "lane la holds only its own events"  "2" "$(wc -l < "$MEM/lanes/la/ledger.md" | tr -d ' ')"
t  "lane lb holds only its own events"  "1" "$(wc -l < "$MEM/lanes/lb/ledger.md" | tr -d ' ')"
t  "la's READ view = project + own"     "3" "$(SMITHY_LANE=la bash "$SCRIPTS/ledger.sh" tail 50 | wc -l | tr -d ' ')"
t  "la cannot see lb's events"          "0" "$(SMITHY_LANE=la bash "$SCRIPTS/ledger.sh" tail 50 | grep -c 'task-3' || true)"
t  "lb cannot see la's events"          "0" "$(SMITHY_LANE=lb bash "$SCRIPTS/ledger.sh" tail 50 | grep -c 'task-2' || true)"
t  "'last' works inside a lane"         "1" "$(SMITHY_LANE=la bash "$SCRIPTS/ledger.sh" last inspect | grep -c 'APPROVED' || true)"
t  "starting an existing lane is refused" "1" \
   "$(bash "$SCRIPTS/lane.sh" start la >/dev/null 2>&1; echo $?)"

echo "--- merge: union in timestamp order, per-lane order preserved ---"
printf '# Smithy State\n- Active job: jobs/demo/\n- Phase: FORGE (task 1 of 3)\n- Base sha: abc1234\n- Last event: old\n- Blockers: none\n- Next step: keep going\n' > "$MEM/STATE.md"
echo "- picked TDD for task-2" > "$MEM/lanes/la/decisions.md"
bash "$SCRIPTS/lane.sh" merge la >/dev/null
t  "lane events folded in"              "3" "$(wc -l < "$MEM/ledger.md" | tr -d ' ')"
t  "DONE still precedes APPROVED"       "yes" \
   "$(awk '/task-2 \| DONE/{d=NR} /task-2 \| APPROVED/{a=NR} END{print (d && a && d<a) ? "yes" : "no"}' "$MEM/ledger.md")"
t  "decisions.md appended"              "1" "$(grep -c 'picked TDD' "$MEM/decisions.md" || true)"
tc "STATE.md Last event refreshed"      "task-2"  "$(grep '^- Last event:' "$MEM/STATE.md")"
tc "...other STATE lines intact"        "abc1234" "$(grep '^- Base sha:' "$MEM/STATE.md")"
tc "...semantic lines NOT invented"     "keep going" "$(grep '^- Next step:' "$MEM/STATE.md")"
t  "merged lane is gone from list"      "0" "$(bash "$SCRIPTS/lane.sh" list | grep -c '^la ' || true)"
t  "...and archived, not deleted"       "1" "$(ls "$MEM/lanes/.merged" | grep -c '^la-' || true)"
t  "no lock left behind"                "no" "$([ -d "$MEM/lanes/.merge-lock" ] && echo yes || echo no)"

echo "--- abandon: events never reach the ledger ---"
before="$(wc -l < "$MEM/ledger.md" | tr -d ' ')"
bash "$SCRIPTS/lane.sh" abandon lb >/dev/null
t  "ledger unchanged by abandon"        "$before" "$(wc -l < "$MEM/ledger.md" | tr -d ' ')"
t  "abandoned lane archived"            "1" "$(ls "$MEM/lanes/.merged" | grep -c 'lb-abandoned' || true)"
t  "abandoning an unknown lane fails"   "1" "$(bash "$SCRIPTS/lane.sh" abandon nope >/dev/null 2>&1; echo $?)"

echo "--- merge-all ---"
new_repo r3
bash "$SCRIPTS/lane.sh" start m1 >/dev/null; bash "$SCRIPTS/lane.sh" start m2 >/dev/null
SMITHY_LANE=m1 bash "$SCRIPTS/ledger.sh" append forge demo t1 DONE m1.md
SMITHY_LANE=m2 bash "$SCRIPTS/ledger.sh" append forge demo t2 DONE m2.md
bash "$SCRIPTS/lane.sh" merge-all >/dev/null
t  "merge-all folds every lane"         "2" "$(wc -l < "$MEM/ledger.md" | tr -d ' ')"
t  "no active lanes remain"             "1" "$(bash "$SCRIPTS/lane.sh" list | grep -c 'no active lanes' || true)"

echo "--- worktree.sh opens and markers stay untracked ---"
new_repo r4
WT="$(bash "$SCRIPTS/worktree.sh" create demo task-7 2>/dev/null)"
t  "worktree created"                   "yes" "$([ -d "$WT" ] && echo yes || echo no)"
t  "lane dir opened for it"             "yes" "$([ -d "$MEM/lanes/demo-task-7" ] && echo yes || echo no)"
t  "lane marker dropped"                "demo-task-7" "$(cat "$WT/.smithy-lane")"
cd "$WT"
t  "scripts inside it resolve the lane" "demo-task-7" "$(lane_of)"
t  "...via the marker, not env"         "marker:.smithy-lane" "$(bash "$SCRIPTS/paths.sh" lane-source)"
t  "worktree tree reads CLEAN"          "" "$(git status --short)"
bash "$SCRIPTS/ledger.sh" append forge demo task-7 DONE w.md
t  "its events go to its lane"          "1" "$(wc -l < "$MEM/lanes/demo-task-7/ledger.md" | tr -d ' ')"
t  "...not the project ledger"          "no" "$([ -f "$MEM/ledger.md" ] && echo yes || echo no)"
echo y > new.txt && git add -A && git commit -qm "feat: w" >/dev/null 2>&1
t  "agent's 'add -A' skips the markers" "0" "$(git show --stat --name-only --format= HEAD | grep -c 'smithy' || true)"
cd "$R"
bash "$SCRIPTS/worktree.sh" absorb demo task-7 >/dev/null 2>&1
out="$(bash "$SCRIPTS/worktree.sh" remove "$WT" --force 2>&1)"
tc "remove flags the unmerged lane"     "still unmerged" "$out"
t  "...and does not merge it itself"    "yes" "$([ -d "$MEM/lanes/demo-task-7" ] && echo yes || echo no)"
cd "$BASE"

echo "=== FAILURES: $fails ==="
exit $fails
