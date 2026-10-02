# Persona Modes — how each agent uses a persona

A persona is a short file that gives an agent a point of view (a security
engineer, an end user…). Built-in personas live in
`${CLAUDE_PLUGIN_ROOT}/references/personas/masters/` (craft) and `${CLAUDE_PLUGIN_ROOT}/references/personas/patrons/`
(experience). Project personas live in `<memory>/personas/` (from
`/smithy:commission`).

The same persona file means something different depending on WHO reads it.
A brief's `## Persona` section names the file(s); the agent uses them in
its mode below. What a persona asks for is a REQUIREMENT, not a suggestion.

## The four modes

| Agent | Mode | The persona's hunt list becomes… | Its severity calibration becomes… |
|---|---|---|---|
| inspector | **judgment lens** | findings to hunt for | how findings are scored |
| forger / jigsmith | **build constraints** | things you must NOT create — build so the hunt finds nothing | the priority order when two constraints pull apart |
| temperer | **test lens** | test cases to write (each hunt item = something to prove absent) | how findings are priced |
| annealer | **investigation lens** | where to look FIRST for the cause | how far the damage likely reaches |

A persona shapes the WORK, never the report format. Each agent keeps its own
report and envelope. Only the inspector follows a persona's "Output"
section; every other agent ignores it.

## Who gets which persona (the dispatching skill picks, and writes it in the brief)

| Dispatch | Persona file(s) | Max |
|---|---|---|
| forger/jigsmith — every task | masters/engineer.md (default) | 2 |
| … task touches auth, input, payments or data | + masters/security.md | 2 |
| … UI task | + masters/uiux.md (accessibility-heavy) OR masters/designer.md (identity-heavy) | 2 |
| … service, config or infra task | + masters/sre.md | 2 |
| temperer — ring-test | masters/qa.md | 1 |
| temperer — wield | patrons/end-user.md + project personas (+ patrons/support.md for error-path flows) | 2 + project |
| temperer — proof | masters/sre.md | 1 |
| temperer — hone | none (the playbooks carry the rules) | 0 |
| annealer — ordinary logic bug | masters/engineer.md (default) | 1 |
| annealer — security, prod-infra or UX symptom | security.md / sre.md / end-user.md INSTEAD | 1 |
| inspector | set by each skill (inspect alone = none, guild = picked from the diff, blueprint deep pass = 1–3, burnish = designer) | per skill |

All files above are under `${CLAUDE_PLUGIN_ROOT}/references/personas/`.

**Why these limits:** each persona costs ~450 tokens inside the agent's own
separate context — cheap. But two points of view is the most an agent can
really hold while building; more and they blur. The temperer never gets
engineer.md: its edge-case duty already lives in the stack playbooks and
qa.md, so a third copy adds noise, not rigor.
