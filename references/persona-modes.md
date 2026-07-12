# Persona Modes — how each agent type consumes a persona overlay

Personas live at `${CLAUDE_PLUGIN_ROOT}/references/personas/` (masters +
patrons) and `docs/smithy/personas/` (project personas from commission).
The same persona file means something different depending on WHO reads it.
A brief's `## Persona` section names the overlay file(s); the agent adopts
them per its mode below. Persona constraints are REQUIREMENTS, not
suggestions.

## The four modes

| Agent | Mode | The persona's hunt list becomes… | Severity calibration becomes… |
|---|---|---|---|
| inspector | **judgment lens** (unchanged) | findings to hunt | finding scores |
| forger / jigsmith | **build constraints** | things you must NOT create — build so the hunt comes up empty | the priority order when constraints tension |
| temperer | **test lens** | test cases to write (each hunt item = something to prove absent) | how findings are priced |
| annealer | **investigation lens** | where to look FIRST for the mechanism | how bad the blast radius likely is |

Output contracts do NOT change with the overlay: each agent keeps its own
report format; the persona shapes the WORK, not the envelope. Ignore a
persona's "Output" section unless you are the inspector.

## Selection (done by the dispatching skill, recorded in the brief)

| Dispatch | Overlay(s) | Cap |
|---|---|---|
| forger/jigsmith — every task | masters/engineer.md (default) | 2 |
| … task touches auth/input/payments/data | + masters/security.md | 2 |
| … UI task | + masters/uiux.md OR masters/designer.md (a11y-heavy vs identity-heavy) | 2 |
| … service/config/infra task | + masters/sre.md | 2 |
| temperer — ring-test | masters/qa.md | 1 |
| temperer — wield | patrons/end-user.md + project personas (+ patrons/support.md for error-path flows) | 2 + project |
| temperer — proof | masters/sre.md | 1 |
| temperer — hone | none (playbooks carry the discipline) | 0 |
| annealer — ordinary logic bug | masters/engineer.md (default) | 1 |
| annealer — security / prod-infra / UX symptom | security.md / sre.md / end-user.md INSTEAD | 1 |
| inspector | contextual, as each skill defines (solo=none, guild=diff-selected roster, blueprint deep pass=1–3, burnish=designer) | skill-defined |

Rationale for the caps: overlays ride in ISOLATED contexts (~450 tok each)
— cheap, but two lenses is the most an agent can genuinely hold while
building; beyond that they blur. The temperer never gets engineer.md: its
edge-case duty already lives in the stack playbooks and qa.md — a third
copy is noise, not rigor.
