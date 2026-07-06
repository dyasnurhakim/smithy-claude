# Spec — Personas, Git Guard Rails, Inter-Agent Envelope (v0.4.0)

Approved in brainstorming 2026-07-07. Three features, one release.

## 1. Persona system

Two plugin-shipped families (overlay files injected by path at dispatch — the
inspector agent stays ONE agent) plus a project-level generator.

**Guild masters** (`references/personas/masters/`) — craft: is it built right?
engineer, security, qa (conditional: behavior/tests), uiux (conditional:
frontend files), sre (conditional: infra/perf/config). engineer + security
always fire.

**Patrons** (`references/personas/patrons/`) — experience: is it the right
thing? end-user + product (any user-facing diff), marketing (public
surface/copy), support (error-handling/config diffs).

**`/smithy:guild`** — production-readiness panel. One whole-job review package
(job base..HEAD), personas selected by diff content, dispatched as PARALLEL
`smithy:inspector` agents (one persona overlay each, routing role `review`),
each writes `reports/guild-<persona>.md`. Controller synthesizes: dedupe by
fingerprint, findings tagged `craft`/`experience`, evaluate-don't-obey rules
apply, single verdict `PRODUCTION_READY | NOT_READY` (both tag groups must be
clean) in `reports/guild-verdict.md`. Pipeline position: FORGE → GUILD →
TEMPER, gated by config `review_panel: auto | always | never` (auto = fire at
end of FORGE; never = skip; always = also per-task panels are NOT done — always
still means end-of-job only, the word governs standalone prompting).

**`/smithy:commission`** — generates project-level test personas at
`docs/smithy/personas/*.md` from the project's role definitions (spec, README,
role/permission enums greppable in code, or user interview). Idempotent;
flags roles found in code with no persona. Same overlay format.

**Consumption**: wield gains persona mode — when `docs/smithy/personas/`
exists, QA flows run per persona within their permission boundaries +
cross-persona permission checks (Critical if crossed). guild's patron-end-user
loads project personas when present.

## 2. Git guard rails

`scripts/guard.sh` + PreToolUse Bash hook (deterministic; exit 2 blocks).
Enforces ONLY where `<project>/docs/smithy/` exists.

- Always blocked: `git push` (unless one-shot token), `reset --hard`,
  `rebase`, `branch -D`, `clean -f`, `commit --amend`, force flags,
  `rm -rf` on absolute/`~`/`..` paths.
- `git commit`: requires job-scoped grant `docs/smithy/.git-grant` — written
  when the user approves the PLAN gate (approval = authorizing that plan's
  task commits), revoked at job end and by handover.
- Push: `guard.sh allow-push-once` mints a one-shot token
  (`docs/smithy/.push-once`), consumed by the next push. Only a live user yes
  should trigger minting.
- Tokens gitignored via `docs/smithy/.gitignore` (init-memory writes it).
- Creed meta-rule: user rules (global + project CLAUDE.md) OVERRIDE smithy
  protocol; surface conflicts, never silently pick.

## 3. Inter-agent envelope

Every brief/report/verdict opens with a YAML envelope between `---smithy` and
`---` markers, then the human markdown body. Contract in
`references/envelope.md`; helper `scripts/envelope.sh` (get/validate).

Fields: `schema: 1`, `kind` (brief | impl-report | review-verdict | rca |
test-report | guild-verdict | persona), `job`, `unit`, `agent`, `status`,
`confidence` (reports), `artifacts[]`, `key_facts[]`, `concerns[]`,
`next_action`. `key_facts`/`concerns` are the loss-prevention channel:
controllers copy unresolved ones forward into the next brief's envelope.
Envelope replaces the Status-line contract as primary machine-read; defensive
rule: missing/invalid envelope → treat as DONE_WITH_CONCERNS and read the body.
