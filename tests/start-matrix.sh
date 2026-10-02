#!/usr/bin/env bash
# start.sh test matrix. Run: bash tests/start-matrix.sh
set -u
S="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/start.sh"
D="$(mktemp -d)"
trap 'cd /; rm -rf "$D"' EXIT
export SMITHY_HOME="$D/home"; mkdir -p "$SMITHY_HOME"
unset SMITHY_MEM_DIR SMITHY_LANE
mkdir -p "$D/repo" && cd "$D/repo" && git init -q -b main
fails=0
t() { if [ "$2" = "$3" ]; then printf 'PASS  %s\n' "$1"; else printf 'FAIL! %s (want %s, got %s)\n' "$1" "$2" "$3"; fails=$((fails + 1)); fi; }
c() { case "$3" in *"$2"*) printf 'PASS  %s\n' "$1" ;; *) printf 'FAIL! %s (want ~%s, got %s)\n' "$1" "$2" "$3"; fails=$((fails + 1)) ;; esac; }
job() { bash "$S" "$@" 2>/dev/null | sed -n 's/^job: \([^ ]*\) .*/\1/p'; }

echo '{"memory":{"location":"ask"}}' > "$SMITHY_HOME/config.json"
bash "$S" jig >/dev/null 2>&1; t "location undecided → exit 3 (ask the user)" 3 "$?"
c "…and the output tells you to ask" "ASK THE USER" "$(bash "$S" jig 2>&1)"

echo '{"memory":{"location":"repo"}}' > "$SMITHY_HOME/config.json"
out="$(bash "$S" jig)"; t "first run creates memory → exit 0" 0 "$?"
t "STATE.md created" yes "$([ -f docs/smithy/STATE.md ] && echo yes || echo no)"
t "no active job → auto makes a new slug" "jig-$(date -u +%Y-%m-%d)" "$(echo "$out" | sed -n 's/^job: \([^ ]*\) .*/\1/p')"
c "STARTED is logged" "| jig | jig-" "$(cat docs/smithy/ledger.md)"

t "new twice → unique slugs" "strike-$(date -u +%Y-%m-%d)-2" "$( job strike new >/dev/null; job strike new )"
t "explicit slug is used" "user-auth" "$(job forge user-auth)"
t "explicit slug makes its job folder" yes "$([ -d docs/smithy/jobs/user-auth/reports ] && echo yes || echo no)"
bash "$S" forge Bad_Slug >/dev/null 2>&1; t "non-kebab slug refused → exit 2" 2 "$?"

printf '# Smithy State\n- Active job: jobs/user-auth/\n- Phase: FORGE (task 2 of 3)\n- Base sha: abc\n' > docs/smithy/STATE.md
t "active job → auto reuses it" "user-auth" "$(job ring-test)"
t "active job → new still makes a new one" "anneal-$(date -u +%Y-%m-%d)" "$(job anneal new)"
printf '# Smithy State\n- Active job: jobs/user-auth/\n- Phase: IDLE\n- Base sha: abc\n' > docs/smithy/STATE.md
t "finished (IDLE) job is not reused" "inspect-$(date -u +%Y-%m-%d)" "$(job inspect)"

mkdir -p docs/smithy/lanes/.merged/old-lane
c "merged lanes only → no UNMERGED warning" "recent events" "$(bash "$S" ring-test)"
t "merged-only lanes are not reported" no "$(bash "$S" ring-test | grep -q UNMERGED && echo yes || echo no)"

bash "$S" ../../escape >/dev/null 2>&1; t "a skill name with ../ is refused → exit 2" 2 "$?"
printf '# Smithy State\n- Active job: jobs/../../pwned/\n- Phase: FORGE\n' > docs/smithy/STATE.md
t "an odd Active job in STATE is ignored (new slug instead)" "jig-$(date -u +%Y-%m-%d)-2" "$(job jig)"
t "…and nothing is created outside memory" no "$([ -e "$D/pwned" ] || [ -e "$D/repo/docs/pwned" ] && echo yes || echo no)"
rm -rf docs/smithy/jobs/race-*
for i in 1 2 3 4 5 6; do bash "$S" race new >/dev/null 2>&1 & done; wait
t "6 runs at once get 6 different slugs" 6 "$(ls -d docs/smithy/jobs/race-* | wc -l)"

cd "$D" && bash "$S" x >/dev/null 2>&1; t "outside a git repo → exit 4" 4 "$?"
bash "$S" >/dev/null 2>&1; t "no skill name → exit 2" 2 "$?"

echo
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
