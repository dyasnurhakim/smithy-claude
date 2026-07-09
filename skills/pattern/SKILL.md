---
name: pattern
description: "Design creation: subject-grounded direction with HTML previews, tokens, states, voice → docs/smithy/DESIGN.md. Triggers: 'pattern', 'design system', 'make it look good'."
---

# Pattern — Design Creation

(The patternmaker shapes the form before anything is cast. UI built without
a pattern comes out template-shaped.)

Read `${CLAUDE_PLUGIN_ROOT}/references/creed.md` and `${CLAUDE_PLUGIN_ROOT}/references/memory.md` first.
If `docs/smithy/` is missing, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/init-memory.sh`.
Log: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append pattern <slug-or-'-'> design STARTED -`

Output: `docs/smithy/DESIGN.md` — the project's design source of truth,
consumed by blueprint/forge briefs for UI tasks, judged against by
master-uiux and `/smithy:burnish`.

## Checklist (create a todo per item)

1. Understand the product, audience, and brand intent (ask, don't assume)
2. Propose 2–3 distinct directions with visual previews; user picks
3. Define the full system (tokens, type, states, motion, voice)
4. Write DESIGN.md + final preview; user approves
5. Log + tell consumers

Adopt the `master-designer` persona
(`${CLAUDE_PLUGIN_ROOT}/references/personas/masters/designer.md`) for the
design thinking in this skill — its default-test and calibration bind here.

## 1. Understand

Read the spec/README; look at any existing UI. Then ask (batched, with
evidence-derived defaults): who uses this and in what context; three brand
adjectives ("calm, clinical, trustworthy" ≠ "bold, playful, loud");
light/dark/both; existing brand constraints (logo, mandated colors);
2–3 products whose look the user admires; accessibility floor (WCAG AA
default). Never invent brand intent — it is the one thing you cannot grep.
Name the SUBJECT concretely (the product, its audience, each page's single
job) — the subject's world is where distinctive choices come from.

## 2. Direction — never default to "clean minimal"

Propose 2–3 DISTINCT directions from genuinely different families (e.g.
editorial/magazine, neo-brutalism, glassmorphism with real depth, Swiss/
International, dark or light luxury, bento, retro-futurism) — each with:
one-line thesis, palette swatch, type pairing, and one signature move
(the thing a screenshot would be recognized by).

**Build one self-contained preview HTML per direction** at
`docs/smithy/design/previews/<direction>.html` (inline CSS, no CDNs; a hero,
a form with states, a card, a table fragment). Previews are the proof —
directions are chosen by looking, not by reading adjectives.
AskUserQuestion: pick / blend / reject-and-repropose.

### Anti-template gate (binding for the chosen direction)

Banned as unexamined defaults: the shadcn/Tailwind stock look; centered-hero
+ gradient-blob + generic CTA; uniform card grids with no hierarchy;
identical radius/spacing/shadow everywhere; gray-on-white with one
decorative accent; default font stacks without a stated reason — plus the
three current AI-design clichés: (1) warm cream (~#F4F1EA) + high-contrast
serif + terracotta accent, (2) near-black + one acid-green/vermilion accent,
(3) broadsheet hairlines + zero radius + dense columns. All are legitimate
when the USER asks for them; none may be where an unspent freedom lands.

**Ground the direction in the subject's own world** — its materials,
instruments, vernacular. A clinic, a forge, and a synth store must not
share a hero. Every direction names a **signature element**: the single
thing this design is remembered by. Spend the boldness there; keep
everything around it quiet (before shipping, remove one accessory).
The self-test: "would I have proposed this direction for any similar
brief?" If yes, revise before showing the user.

## 3. Define the system

Concrete values, not vibes — every token has a value and a usage rule:

- **Color**: OKLCH palette — surface/text/accent/semantic (success/warn/
  danger/info), both themes if applicable, every text/surface pair passing
  the agreed contrast floor (state the computed ratios).
- **Typography**: family pairing + why; scale (clamp() for fluid sizes);
  weights; line-height rules.
- **Spacing & shape**: spacing scale, radius scale, shadow/elevation levels
  and when each is used.
- **States**: hover/focus/active/disabled/loading/empty/error for the core
  components (button, input, card, table, dialog) — described concretely.
- **Motion**: durations, easings, what moves and what never moves;
  `prefers-reduced-motion` behavior.
- **Voice — copy is design material**: end-user vocabulary, never system
  vocabulary ("notifications", not "webhook config"); controls say exactly
  what happens ("Save changes", not "Submit") and keep the same name through
  the whole flow; errors state what went wrong and how to fix it — direct,
  never apologetic or vague; empty states are invitations to act, not mood.

## 4. Write DESIGN.md + final preview

`docs/smithy/DESIGN.md` is a human document — plain markdown, no envelope:
Direction (thesis + signature move), Tokens (as CSS custom properties in a
code block, copy-paste ready), Typography, States, Motion, Voice,
Anti-template gate results, Do/Don't examples. Update the chosen preview to match the final
system exactly — it is the visual acceptance test. User reviews BOTH and
approves before this skill exits.

## 5. Log + handoff

`ledger.sh append pattern <slug-or-'-'> design DONE docs/smithy/DESIGN.md`;
≤3-line decisions.md entry (direction chosen, alternatives rejected).

Tell the user: UI task briefs must now list DESIGN.md in context files
(blueprint does this automatically when it exists); master-uiux and
`/smithy:burnish` will judge against it.

## Red flags

| Thought | Reality |
|---|---|
| "Clean and minimal is a safe direction" | It's the absence of a direction. Pick a family with a signature move. |
| "I'll describe the directions in prose, skip previews" | Nobody can choose a look from adjectives. The preview IS the proposal. |
| "Default system fonts are fine" | Only as a stated choice with a reason — never as an unexamined default. |
| "Contrast probably passes" | Compute it. State the ratios in DESIGN.md. |

Handoff: "DESIGN.md written — UI work in `/smithy:forge` builds against it; run `/smithy:burnish` anytime to audit the live app against it."
