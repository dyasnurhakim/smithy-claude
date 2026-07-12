---
name: ring-test
description: "Unit tests per the stack playbook (write missing, run, flag flakes). Triggers: 'ring-test', 'unit test this'."
---

# Ring-Test — Unit Tests

(A ring test taps metal and listens for cracks — flaw detection per piece.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/stacks.md`,
and `${CLAUDE_PLUGIN_ROOT}/references/dispatch.md` first.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append temper <slug> ring-test STARTED -`

## Process

1. **Detect the stack:** `bash ${CLAUDE_PLUGIN_ROOT}/scripts/stack-detect.sh`.
   Pick the playbook from this skill's `references/` dir by the `stack=`
   value: `ts.md` (js/ts), `python.md`, `go.md`, `java.md`, `rust.md`.
   `stack=unknown` → use the generic rules in stacks.md and confirm the test
   command with the user first.

2. **Determine scope.** Pipeline mode: the tasks in `jobs/<slug>/plan.md` —
   test the behaviors its success criteria name. Standalone: ask the user
   which files/behaviors, or default to code changed since the base sha.

3. **Write the test brief** `jobs/<slug>/briefs/ring-test.md` (dispatch.md
   template): playbook path, target files, behaviors to cover, the runner
   invocation from the playbook, report path `reports/test-unit.md`.
   Requirements include: one behavior per test, AAA structure, descriptive
   names, no snapshot-everything, do not touch production source.
   `## Persona`: masters/qa.md (test lens per persona-modes.md).

4. **Dispatch `smithy:temperer`** (routing role `testing`; effort banner; paths only).

5. **Read the report.** FLAKY findings are failures of determinism — surface
   them, never average them away. If the temperer reports FAIL because a source
   change is needed, that goes to `/smithy:forge` (new task) or `/smithy:anneal`
   (if unexpected) — never let the temperer "fix" source.

6. **Log:** `ledger.sh append temper <slug> ring-test <PASS|FAIL|PARTIAL> reports/test-unit.md`

## Exit criteria

Suite green (or failures documented with repro commands). Coverage of every
plan success criterion either exists or is explicitly listed as a gap.

Handoff: "FAIL → `/smithy:anneal`. Next: `/smithy:wield` for functional QA."
