---
name: pattern
description: "Design creation: a direction grounded in the product's own world, shown as HTML previews, then tokens, states, motion and voice written to the project DESIGN.md. Triggers: 'pattern', 'design system', 'make it look good'."
---

# Pattern — Design Creation

A patternmaker shapes the form before anything is cast. UI built without a
pattern comes out looking like a template.

```
understand ──▶ 2–3 directions ──▶ user picks ──▶ full system ──▶ DESIGN.md
(ask)          (HTML previews)    (by looking)   (real values)   + final preview, user approves
```

DESIGN.md is the project's design rulebook. Blueprint puts it in UI task
briefs, forge builds against it, and `/smithy:burnish` and
`${CLAUDE_PLUGIN_ROOT}/references/personas/masters/uiux.md` judge against it.

## Start

1. `bash ${CLAUDE_PLUGIN_ROOT}/scripts/start.sh pattern new` — read its summary.
2. Read once per session: `${CLAUDE_PLUGIN_ROOT}/references/creed.md`, `${CLAUDE_PLUGIN_ROOT}/references/memory-card.md`,
   `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/designer.md` (you think as this persona in
   this skill — its default test and severity calibration apply).

## Needs

| Needs | If it exists | If it is missing |
|---|---|---|
| Product context | spec.md, README, existing UI — read them | ask the step 1 questions; that is enough to start |
| Brand intent | the user's answers | ask — it is the one thing you cannot grep. Never invent it |
| An existing `<memory>/DESIGN.md` | ask: revise it, or replace it? | create it |
| A browser to view previews | the user opens the HTML files | name the file paths; the user opens them by hand |

Paths below are relative to the `memory:` folder start.sh printed.

## Steps

1. **Understand** — read the spec/README and look at any existing UI.
   Lookup (creed §10): memory — past design choices or rejected directions
   for this project. Then ask in one batch, each with a default drawn from
   what you read:
   1. Who uses this, and where (desk, phone, on the move)?
   2. Three brand adjectives ("calm, clinical, trustworthy" is not "bold, playful, loud").
   3. Fixed brand rules (logo, required colors)?
   4. Two or three products whose look they admire?
   5. Light, dark or both — and the accessibility floor (default WCAG AA)?
   Then name the SUBJECT plainly: the product, its audience, and each
   page's single job. The subject's world is where distinctive choices
   come from.
   → verify: answers recorded; the subject is written in one paragraph.

2. **Directions — never default to "clean minimal"** — propose 2–3
   directions from truly different families (for example editorial,
   neo-brutalism, glass with real depth, Swiss, dark or light luxury,
   bento, retro-futurism). Each has: a one-line thesis, a palette swatch,
   a type pairing, and one **signature move** (the thing a screenshot is
   recognized by). Ground each one in the subject's world — its materials,
   tools, words. A clinic, a forge and a synth store must not share a hero.
   Self-test before showing: "would I propose this for any similar brief?"
   Yes → revise it.
   → verify: each direction passes the anti-template gate below.

3. **Previews** — build one self-contained HTML file per direction at
   `design/previews/<direction>.html` (inline CSS, no CDNs). Each shows a
   hero, a form with its states, a card, and a table fragment. People
   choose a look by seeing it, not by reading adjectives. Ask the user:
   pick one / blend / reject and re-propose.
   → verify: one preview file per direction; the user's choice is recorded.

4. **Define the system** — real values, not vibes. Every token has a value
   and a rule for when to use it:
   - **Color**: an OKLCH palette (OKLCH = a color format where equal steps
     look equally different) — surface, text, accent, and success / warn /
     danger / info; both themes if asked. Every text/surface pair passes
     the contrast floor — compute the ratios and write them down.
   - **Typography**: the pairing and why; a scale (`clamp()` for fluid
     sizes); weights; line-height rules.
   - **Spacing and shape**: spacing scale, radius scale, shadow levels and
     when each is used.
   - **States**: hover, focus, active, disabled, loading, empty, error — for
     button, input, card, table, dialog — described concretely.
   - **Motion**: durations, easings, what moves and what never moves, and
     what happens under `prefers-reduced-motion`.
   - **Voice — copy is design material**: the user's words, never the
     system's ("notifications", not "webhook config"). Buttons say exactly
     what happens ("Save changes", not "Submit") and keep that name through
     the whole flow. Errors say what went wrong and how to fix it — direct,
     never apologetic or vague. Empty states invite an action, not a mood.
   → verify: every token has a value and a usage rule; contrast ratios are written down.

5. **Write DESIGN.md + final preview** — `DESIGN.md` is a document for
   people: plain markdown, no envelope. Sections: Direction (thesis +
   signature move), Tokens (CSS custom properties in a code block, ready to
   paste), Typography, States, Motion, Voice, Anti-template gate results,
   Do / Don't examples. Update the chosen preview to match the final system
   exactly — it is the visual acceptance test. The user reviews BOTH and
   approves before this skill ends.
   → verify: the user said yes to DESIGN.md and the final preview.

6. **Log and hand off** —
   `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ledger.sh append pattern <slug> design DONE DESIGN.md`;
   a decisions.md entry of ≤3 lines (direction chosen, directions rejected).
   Tell the user: UI task briefs must list DESIGN.md in their context files
   (blueprint does this when the file exists); `${CLAUDE_PLUGIN_ROOT}/references/personas/masters/uiux.md`
   and `/smithy:burnish` judge against it.
   → verify: the ledger line and decisions entry exist.

## Anti-template gate (binds the chosen direction)

Not allowed as unexamined defaults:

- the stock shadcn/Tailwind look;
- centered hero + gradient blob + generic call-to-action;
- uniform card grids with no hierarchy;
- the same radius, spacing and shadow everywhere;
- gray on white with one decorative accent;
- default font stacks with no stated reason;
- the three current AI-design clichés: (1) warm cream (~#F4F1EA) +
  high-contrast serif + terracotta accent, (2) near-black + one acid-green
  or vermilion accent, (3) newspaper hairlines + zero radius + dense columns.

All of these are fine when the USER asks for them. None may be where an
unused freedom lands by default. Every direction names its **signature
element** — the one thing it is remembered by. Spend the boldness there and
keep everything around it quiet. Before shipping, remove one accessory.

## Done when

- [ ] the subject paragraph and the user's answers are recorded
- [ ] 2–3 directions, each with a preview HTML file under `design/previews/`
- [ ] the chosen direction passed the anti-template gate (results in DESIGN.md)
- [ ] DESIGN.md has every token with a value and a rule, and computed contrast ratios
- [ ] the final preview matches DESIGN.md, and the user approved both
- [ ] ledger DONE line and decisions.md entry written

## Output

`<memory>/DESIGN.md` · `<memory>/design/previews/<direction>.html` · a decisions.md entry.

`Next: /smithy:burnish — check the live app against DESIGN.md` · or `Next: /smithy:blueprint — plan the UI work that uses it`.

## Red flags

| Thought | Reality |
|---|---|
| "Clean and minimal is a safe direction" | It is the absence of a direction. Pick a family with a signature move. |
| "I'll describe the directions in prose, skip previews" | Nobody can choose a look from adjectives. The preview IS the proposal. |
| "Default system fonts are fine" | Only as a stated choice with a reason — never as an unexamined default. |
| "Contrast probably passes" | Compute it. Write the ratios in DESIGN.md. |
| "I can guess the brand from the code" | Brand intent cannot be grepped. Ask. |
