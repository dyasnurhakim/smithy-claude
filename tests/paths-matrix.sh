#!/usr/bin/env bash
set -u
# Self-contained paths.sh / init-memory.sh matrix. Run: bash tests/paths-matrix.sh
# Covers all five memory-dir resolution rules + the two-tier config layers.
SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts"
BASE="$(mktemp -d)"; trap 'rm -rf "$BASE"' EXIT
fails=0

t() { # t <desc> <expect> <actual>
  if [ "$3" = "$2" ]; then printf 'PASS  %-46s %s\n' "$1" "$3"
  else printf 'FAIL! %-46s want=%s got=%s\n' "$1" "$2" "$3"; fails=$((fails+1)); fi
}
tc() { # tc <desc> <expect-substr> <actual>
  case "$3" in *"$2"*) printf 'PASS  %-46s %s\n' "$1" "$3" ;;
  *) printf 'FAIL! %-46s want~%s got=%s\n' "$1" "$2" "$3"; fails=$((fails+1)) ;; esac
}
mem()  { bash "$SCRIPTS/paths.sh" mem; }
src()  { bash "$SCRIPTS/paths.sh" mem-source; }

# Sets R (repo path) and SMITHY_HOME, then cds in. NOT command-substituted —
# it must mutate the caller's cwd and environment, which a subshell cannot.
new_repo() { # new_repo <name>
  R="$BASE/$1"
  mkdir -p "$R" && cd "$R" && git init -q -b main
  git config user.email t@t.local && git config user.name T
  export SMITHY_HOME="$BASE/$1-home"
  mkdir -p "$SMITHY_HOME"
  unset SMITHY_MEM_DIR
}

echo "--- rule 5: nothing configured -> undecided, never guessed ---"
new_repo r5
t  "provisional path is in-repo"        "$R/docs/smithy" "$(mem)"
t  "source says the choice is unmade"   "unset:ask"      "$(src)"
out="$(bash "$SCRIPTS/init-memory.sh" 2>&1)"; rc=$?
t  "init refuses to guess (exit 3)"     "3"              "$rc"
tc "refusal names the alternatives"     "--external"     "$out"
t  "nothing was created"                "no"             "$([ -d "$R/docs/smithy" ] && echo yes || echo no)"

echo "--- rule 5: global memory.location decides for NEW projects ---"
new_repo r5b
bash "$SCRIPTS/config.sh" set global memory.location external >/dev/null
t  "global says external"               "default:external" "$(src)"
tc "external path under \$SMITHY_HOME"  "$SMITHY_HOME/projects/" "$(mem)"
bash "$SCRIPTS/config.sh" set global memory.location repo >/dev/null
t  "global says repo"                   "default:repo"   "$(src)"
t  "repo path is docs/smithy"           "$R/docs/smithy" "$(mem)"

echo "--- rule 4: an existing in-repo dir wins (back-compat) ---"
new_repo r4
bash "$SCRIPTS/config.sh" set global memory.location external >/dev/null
mkdir -p "$R/docs/smithy"
t  "existing docs/smithy beats global"  "existing:docs/smithy" "$(src)"
t  "...and resolves there"              "$R/docs/smithy" "$(mem)"

echo "--- rule 3: registry, fully outside the repo ---"
new_repo r3
EXT="$BASE/r3-elsewhere"
bash "$SCRIPTS/paths.sh" set-mem "$EXT" >/dev/null
t  "registry resolves"                  "registry:projects.tsv" "$(src)"
t  "...to the registered dir"           "$EXT"           "$(mem)"
t  "registry lives outside the repo"    "no"             "$([ -e "$R/.smithy-path" ] && echo yes || echo no)"
t  "repo working tree untouched"        ""               "$(git -C "$R" status --porcelain)"
bash "$SCRIPTS/paths.sh" unset-mem >/dev/null
t  "unset-mem reverts resolution"       "unset:ask"      "$(src)"

echo "--- rule 2: in-repo pointer file ---"
new_repo r2
PTR_TARGET="$BASE/r2-pointed"
printf '# a comment line\n\n%s\n' "$PTR_TARGET" > "$R/.smithy-path"
t  "pointer resolves"                   "pointer:.smithy-path" "$(src)"
t  "...skipping comments and blanks"    "$PTR_TARGET"    "$(mem)"
printf '  ../r2-relative  \n' > "$R/.smithy-path"
t  "relative pointer -> repo-relative"  "$R/../r2-relative" "$(mem)"
printf '~/smithy-tilde-test\n' > "$R/.smithy-path"
t  "tilde pointer expands"              "$HOME/smithy-tilde-test" "$(mem)"
bash "$SCRIPTS/paths.sh" set-mem "$BASE/r2-registry" >/dev/null
t  "pointer beats registry"             "pointer:.smithy-path" "$(src)"

echo "--- rule 1: env override beats everything ---"
new_repo r1
mkdir -p "$R/docs/smithy"
printf '%s\n' "$BASE/r1-pointed" > "$R/.smithy-path"
bash "$SCRIPTS/paths.sh" set-mem "$BASE/r1-registry" >/dev/null
export SMITHY_MEM_DIR="$BASE/r1-env"
t  "env wins"                           "env:SMITHY_MEM_DIR" "$(src)"
t  "...resolving to the env dir"        "$BASE/r1-env"   "$(mem)"
unset SMITHY_MEM_DIR

echo "--- init-memory --external scaffolds outside the repo ---"
new_repo rext
bash "$SCRIPTS/init-memory.sh" --external >/dev/null 2>&1
M="$(mem)"
t  "resolves via registry afterwards"   "registry:projects.tsv" "$(src)"
tc "memory is under \$SMITHY_HOME"      "$SMITHY_HOME/projects/" "$M"
for f in STATE.md ledger.md decisions.md config.json PROJECT.md; do
  t  "scaffolded $f"                    "yes" "$([ -f "$M/$f" ] && echo yes || echo no)"
done
t  "scaffolded jobs/"                   "yes" "$([ -d "$M/jobs" ] && echo yes || echo no)"
t  "PROJECT.md breadcrumbs the repo"    "yes" "$(grep -qF "$R" "$M/PROJECT.md" && echo yes || echo no)"
t  "repo still clean"                   ""    "$(git -C "$R" status --porcelain)"
t  "no docs/ dir created in the repo"   "no"  "$([ -d "$R/docs" ] && echo yes || echo no)"

echo "--- init-memory --at <dir> --pointer ---"
new_repo rat
bash "$SCRIPTS/init-memory.sh" --at "$BASE/rat-custom" --pointer >/dev/null 2>&1
t  "resolves via the pointer"           "pointer:.smithy-path" "$(src)"
t  "...to the named dir"                "$BASE/rat-custom" "$(mem)"
t  "STATE.md is there"                  "yes" "$([ -f "$BASE/rat-custom/STATE.md" ] && echo yes || echo no)"
t  "pointer file committed-able"        "yes" "$([ -f "$R/.smithy-path" ] && echo yes || echo no)"

echo "--- ledger + guard + review-package follow the relocated dir ---"
new_repo rmoved
bash "$SCRIPTS/init-memory.sh" --external >/dev/null 2>&1
M="$(mem)"
bash "$SCRIPTS/ledger.sh" append forge demo task-1 DONE reports/x.md
t  "ledger wrote outside the repo"      "yes" "$(grep -qF 'task-1' "$M/ledger.md" && echo yes || echo no)"
t  "no ledger left in the repo"         "no"  "$([ -f "$R/docs/smithy/ledger.md" ] && echo yes || echo no)"
tc "ledger tail reads it back"          "task-1" "$(bash "$SCRIPTS/ledger.sh" tail 5)"
bash "$SCRIPTS/guard.sh" grant demo >/dev/null
t  "guard grant wrote outside the repo" "yes" "$([ -f "$M/.git-grant" ] && echo yes || echo no)"
bash "$SCRIPTS/guard.sh" check "git commit -m x" >/dev/null 2>&1
t  "guard ALLOWS commit with grant"     "0"   "$?"
bash "$SCRIPTS/guard.sh" revoke >/dev/null
bash "$SCRIPTS/guard.sh" check "git commit -m x" >/dev/null 2>&1
t  "guard BLOCKS commit after revoke"   "2"   "$?"
bash "$SCRIPTS/guard.sh" check "terraform destroy" >/dev/null 2>&1
t  "guard enforces via relocated mem"   "2"   "$?"
echo x > "$R/a.txt" && git -C "$R" add -A && git -C "$R" commit -qm init
tc "review-package record-base -> STATE" "base=" "$(bash "$SCRIPTS/review-package.sh" record-base)"
t  "base sha landed outside the repo"   "yes" "$(grep -q '^- Base sha: [0-9a-f]' "$M/STATE.md" && echo yes || echo no)"

echo "--- guard stands down where there is no smithy memory ---"
new_repo rbare
bash "$SCRIPTS/guard.sh" check "terraform destroy" >/dev/null 2>&1
t  "unmanaged project: no enforcement"  "0"   "$?"

echo "--- two-tier config writes ---"
new_repo rcfg
bash "$SCRIPTS/init-memory.sh" --in-repo >/dev/null 2>&1
bash "$SCRIPTS/config.sh" set global routing.review.model fable >/dev/null
bash "$SCRIPTS/config.sh" set project routing.review.effort low >/dev/null
t  "global write readable"              "fable" "$(bash "$SCRIPTS/config.sh" get routing.review.model)"
t  "global write attributed"            "global" "$(bash "$SCRIPTS/config.sh" source routing.review.model)"
t  "project write attributed"           "project" "$(bash "$SCRIPTS/config.sh" source routing.review.effort)"
t  "untouched key stays on defaults"    "defaults" "$(bash "$SCRIPTS/config.sh" source routing.planning.model)"
t  "global file is outside the repo"    "yes" "$([ -f "$SMITHY_HOME/config.json" ] && echo yes || echo no)"
t  "booleans parse as JSON not strings" "false" "$(bash "$SCRIPTS/config.sh" set project gates.pause_between_phases false >/dev/null; bash "$SCRIPTS/config.sh" get gates.pause_between_phases)"
t  "lists parse as JSON"                '["proof", "hone"]' "$(bash "$SCRIPTS/config.sh" set project testing.skip '["proof","hone"]' >/dev/null; bash "$SCRIPTS/config.sh" get testing.skip)"
# sparseness: writing the value the layer below already provides prunes the key
bash "$SCRIPTS/config.sh" set project routing.review.model fable >/dev/null
t  "redundant project write is pruned"  "global" "$(bash "$SCRIPTS/config.sh" source routing.review.model)"
# both config.sh (arg validation) and the lib (belt-and-braces) refuse this
bash "$SCRIPTS/config.sh" set defaults routing.review.model haiku >/dev/null 2>&1
t  "refuses to write plugin defaults"   "no"  "$([ $? -eq 0 ] && echo yes || echo no)"
t  "...and left defaults untouched"     "flagship" \
   "$(python3 -c 'import json;print(json.load(open("'"$SCRIPTS"'/../defaults/config.json"))["routing"]["review"]["model"])')"
bash "$SCRIPTS/config.sh" set nonsense routing.review.model haiku >/dev/null 2>&1
t  "refuses an unknown layer name"      "no"  "$([ $? -eq 0 ] && echo yes || echo no)"

echo "--- linked worktrees share ONE memory dir ---"
new_repo rwt
bash "$SCRIPTS/init-memory.sh" --external >/dev/null 2>&1
M="$(mem)"
echo x > "$R/a.txt" && git -C "$R" add -A && git -C "$R" commit -qm init
git -C "$R" worktree add -q -b wt "$BASE/rwt-wt" >/dev/null 2>&1
cd "$BASE/rwt-wt"
t  "worktree resolves the same mem dir" "$M" "$(mem)"
bash "$SCRIPTS/ledger.sh" append forge demo from-worktree DONE r.md
t  "worktree ledger line hits main mem" "yes" "$(grep -qF 'from-worktree' "$M/ledger.md" && echo yes || echo no)"
t  "no stray mem dir in the worktree"   "no"  "$([ -d "$BASE/rwt-wt/docs/smithy" ] && echo yes || echo no)"
cd "$BASE"

echo "=== FAILURES: $fails ==="
exit $fails
