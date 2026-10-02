---
name: commission
description: "Write project test personas from the system's real user roles (code evidence + a short interview). They power per-persona QA in wield and the end-user view in guild. Triggers: 'commission', 'define the users', 'who uses this system'."
---

# Commission — Project Personas

A commission tells the smith who the work is FOR. You cannot judge a blade
without knowing whose hand it must fit.

```
code + docs ──▶ roles found (file:line) ──▶ user fixes the list ──▶ interview ──▶ one file per role
                                                                                 <memory>/personas/
```

These are PROJECT personas: the real users of THIS system. They add to the
plugin's generic personas (`${CLAUDE_PLUGIN_ROOT}/references/personas/masters/`, `patrons/`); they
do not replace them.

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh commission new` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/envelope.md`.

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| A git repo with some code or docs | read it for roles | start.sh exits 4 — say this needs a repo and stop |
| Specs / README / product docs | read them for named user types | rely on code evidence and the interview |
| Existing `<memory>/personas/*.md` | update them in place (step 5) | write new ones |

Nothing else must run first.

## Steps

1. **Find the roles — evidence first, questions second.**
   - Read `<memory>/jobs/*/spec.md`, the README and product docs for named
     user types.
   - Search the code for role definitions: `role`, `permission`, `is_admin`,
     enums like `Role.`, auth middleware, route guards, RBAC tables (role-based
     access control), seed data. Cite `file:line` for every role.
   - Lookup (creed §10, once): a graph tool fits "where are roles checked?";
     memory fits "did we define users before?".
   → verify: every role in the list has a `file:line` or a doc path.

2. **Check the list with the user.** Show it; ask what is missing or wrong:
   "Who else uses this system? Anyone easy to forget — internal admins, API
   consumers, auditors?" Never invent a role that neither the evidence nor
   the user gave you.
   → verify: the user confirmed the final role list.

3. **Interview per role** (AskUserQuestion, at most 4 roles per round). For
   each, offer a default drawn from the evidence so the user can confirm fast:
   - Primary goal: the ONE thing this role uses the system for
   - Top 3 jobs to be done (concrete flows)
   - Permissions: what they CAN and explicitly CANNOT do or see
   - Skill and context (device, environment, how often they use it)
   - Stakes: what a failure costs them (time, money, patients, compliance…)
   → verify: every role has an answer (or a confirmed default) for all five.

4. **Write one persona per role** at `<memory>/personas/<role-slug>.md`, in
   the same shape as the plugin personas so every reader handles them alike:

   ```markdown
   ---smithy
   schema: 1
   kind: persona
   job: "-"
   unit: <role-slug>
   artifacts: []
   key_facts:
     - "project persona — written by commission, source: <spec | code file:line | user>"
   concerns: []
   next_action: "use in wield persona mode / guild (patrons/end-user.md plays it)"
   ---
   # <Role name>
   <2–3 sentences: who they are, skill level, context, how often>
   ## Primary goal
   ## Jobs to be done
   1. <flow: the steps this persona really takes>
   ## Permissions
   - CAN: …
   - CANNOT: …   (each one becomes a cross-persona security check)
   ## What frustrates me
   ## Severity calibration (from MY stakes)
   <what Critical/High mean for this persona — for a nurse, a wrong
   medication display is Critical even if the code "works">
   ```
   → verify: `envelope.sh get <file> kind` prints `persona` for each file.

5. **Re-runs and coverage.** A re-run updates files in place: keep what the
   user said; refresh what came from code. Compare the role evidence with the
   persona files: a role in code with no persona → flag it; a persona whose
   role is gone from code → flag it as maybe stale. Ask; never delete.
   → verify: the flag list was shown (or "none").

6. **Log** — `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append commission <slug> personas DONE personas/`
   and a ≤3-line `decisions.md` entry naming the roles covered.
   → verify: the ledger line exists.

## Who uses these personas (tell the user at the end)

- `/smithy:wield` persona mode: QA flows run PER persona, inside its
  permissions, plus cross-persona checks (a CANNOT that succeeds is Critical).
- `/smithy:guild`: `${CLAUDE_PLUGIN_ROOT}/references/personas/patrons/end-user.md` plays these
  personas instead of a generic user.

## Done when

- [ ] every role cites a `file:line`, a doc path, or "user said"
- [ ] the user confirmed the role list
- [ ] one persona file per role, each with CAN/CANNOT and severity calibration
- [ ] coverage flags shown (missing or maybe-stale personas), nothing deleted
- [ ] ledger line and decisions.md entry written

## Output

`<memory>/personas/<role-slug>.md` (one per role).

`Next: /smithy:wield — QA the app once per persona`

## Red flags

| Thought | Reality |
|---|---|
| "The roles are obvious from the code" | Code shows permissions, not goals or stakes. The interview is where the testing value comes from. |
| "One generic 'user' persona is enough" | Then QA sees one viewpoint and misses every permission boundary. Boundaries live BETWEEN personas. |
| "I'll fill in likely stakes myself" | Made-up stakes mean made-up severities, and QA judges wrong. Ask. |
