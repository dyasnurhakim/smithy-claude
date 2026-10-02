#!/usr/bin/env python3
"""route_guard.py — make smithy's model/effort routing a CODE rule, not a hope.

`references/dispatch.md` §1 asks the controller to pass the routed model as the
subagent tool's `model` parameter, and to put the routed effort banner at the
top of the prompt. Those are prompt rules, and prompt rules slip:
  - the parameter is left out (the subagent then quietly uses the session's model);
  - a cheaper tier is picked on a hunch ("this task is simple");
  - the banner is forgotten, or has the wrong level.
Nothing later notices, because a subagent cannot know what it was *meant* to
run as.

This is the enforcing half — guard.sh's partner for routing. It runs as a
PreToolUse hook (before the tool call) on subagent dispatch, and REWRITES the
call to match config instead of refusing it:

    dispatch ──▶ route_guard ──▶ model + banner fixed ──▶ subagent runs

Fixing costs nothing; refusing costs a turn and ends in the same place.

Contract with the harness (checked against Claude Code 2.1.220):

    {"hookSpecificOutput": {"hookEventName": "PreToolUse",
                            "updatedInput":      {...whole tool_input...},
                            "additionalContext": "..."}}

Three facts about that contract shape the code:

  * `updatedInput` REPLACES the whole tool_input — it is not a patch. So we
    copy the original and change the copy; unknown or future keys are kept.
  * The harness checks it against the tool's own schema. If that check fails,
    the harness THROWS AWAY the whole hook output. So a model value the tool
    cannot accept is reported, never injected — injecting it would quietly
    lose the banner fix too.
  * We never send a `permissionDecision`, on purpose. "allow" would skip the
    user's own permission rules for subagent dispatch. This hook routes; it
    does not grant permission.

Fails open everywhere: a broken guard must never break a dispatch.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_LIB = os.path.join(HERE, "smithy_config.py")
TAG = "[smithy-route-guard]"
TIMEOUT = 10

# Plugin hooks only run under Claude Code (references/harness.md; under Codex
# CLI, dispatch.md §1 is only advice). So if this code runs, the harness IS
# Claude Code. A config that names a DIFFERENT harness lists models this tool
# cannot accept: `sol` would fail the updatedInput check and lose the banner
# fix too. So we warn instead of injecting.
HOOK_HARNESS = "claude"

# The five smithy agents that get dispatched -> their routing role (the agent
# table in dispatch.md). research/planning/mechanical have no agent: the
# controller does that work itself, so there is no dispatch to check.
AGENT_ROLES = {
    "forger": "implementation",
    "jigsmith": "implementation",
    "inspector": "review",
    "annealer": "debugging",
    "temperer": "testing",
}

# The one way out: a brief may name a different role on purpose with a
# `smithy-role: <role>` line (e.g. a forger sent to do mechanical work).
# Any other mismatch is a slip, not a choice.
ROLE_OVERRIDE_RE = re.compile(r"^[ \t]*smithy-role:[ \t]*([A-Za-z][A-Za-z0-9_-]*)[ \t]*$", re.M)

# The general shape of a banner line ("Effort: WORD ..."), so an old banner is
# still found after the registry text changes. The exact registry texts are
# removed too (see strip_banners).
BANNER_LINE_RE = re.compile(r"^[ \t]*Effort:[ \t]*[A-Z]+\b.*(?:\r?\n)?", re.M)


def cfg(*args: str) -> list[list[str]]:
    """Run the config helper and return its TAB-separated rows.

    The helper owns which config layer wins and how the registry is merged.
    Copying either rule here would let the two copies drift apart."""
    out = subprocess.run(
        [sys.executable, CONFIG_LIB, *args],
        capture_output=True, text=True, timeout=TIMEOUT,
    )
    if out.returncode != 0:
        raise RuntimeError(f"smithy_config.py {' '.join(args)} failed: {out.stderr.strip()}")
    return [line.split("\t") for line in out.stdout.splitlines() if line]


def agent_role(subagent_type: str, prompt: str) -> str | None:
    """-> routing role, or None when this dispatch is not ours to check."""
    name = (subagent_type or "").strip()
    if name.startswith("smithy:"):
        name = name[len("smithy:"):]
    elif ":" in name:
        return None  # another plugin's agent that just has the same name
    if name not in AGENT_ROLES:
        return None

    override = ROLE_OVERRIDE_RE.search(prompt or "")
    if override:
        role = override.group(1)
        try:
            known = cfg("roles")[0][0].split()
        except Exception:
            known = []
        if role in known:
            return role
    return AGENT_ROLES[name]


def active_harness() -> str:
    return cfg("harness")[0][0].strip()


def routed(role: str) -> tuple[str, str]:
    """-> (model, effort) for a role, per the effective config."""
    row = cfg("routing", role)[0]
    model = row[1] if len(row) > 1 else ""
    effort = row[2] if len(row) > 2 else ""
    return model, effort


def dispatchable_models() -> set[str]:
    """Model values this harness can really put in the tool's `model` field.

    Read from the registry (kind == "model"), never written in the code — so a
    new release only needs a data edit. Tiers and id_patterns are left out on
    purpose: `flagship` is a config value, not a dispatch value, and a raw id
    that only matches a pattern may not be in the tool's list of allowed values."""
    return {row[0] for row in cfg("models") if len(row) > 2 and row[2] == "model"}


def banner_for(effort: str) -> str:
    for row in cfg("banners", effort):
        if row[0] == effort:
            return row[1] if len(row) > 1 else ""
    return ""


def all_banners() -> list[str]:
    return [row[1] for row in cfg("banners") if len(row) > 1 and row[1]]


def strip_banners(prompt: str, known: list[str]) -> str:
    """Remove every effort banner from a prompt: the exact registry texts and
    any line shaped like a banner. An old banner lower in the prompt is the
    same bug as a wrong one at the top, so its position does not matter."""
    out = prompt
    for text in known:
        out = out.replace(text + "\n", "").replace(text, "")
    out = BANNER_LINE_RE.sub("", out)
    return out.lstrip("\n")


def enforce(tool_input: dict) -> tuple[dict | None, list[str]]:
    """-> (updated tool_input or None if already correct, notes)."""
    prompt = tool_input.get("prompt") or ""
    role = agent_role(tool_input.get("subagent_type", ""), prompt)
    if role is None:
        return None, []

    model, effort = routed(role)
    updated = dict(tool_input)
    notes: list[str] = []

    # ---- model ----------------------------------------------------------
    have = tool_input.get("model")
    if model == "inherit":
        if "model" in updated:
            del updated["model"]
            notes.append(f"dropped model={have} (role '{role}' routes to inherit)")
    elif model:
        harness = active_harness()
        if harness != HOOK_HARNESS:
            notes.append(
                f"WARNING: config sets harness '{harness}', but plugin hooks only run "
                f"under {HOOK_HARNESS} — so '{model}' cannot be used for a dispatch here and "
                f"was NOT injected. Set the harness with /smithy:calibrate."
            )
        elif model in dispatchable_models():
            if have != model:
                updated["model"] = model
                notes.append(f"model {have or 'unset'} -> {model} (role '{role}')")
        elif have != model:
            # Cannot inject: it would fail the updatedInput schema check and
            # lose the banner fix too. Report it instead.
            notes.append(
                f"WARNING: role '{role}' routes to model '{model}', which this harness "
                f"cannot accept as a dispatch value — dispatching as '{have or 'unset'}'. "
                "Fix the routing value with /smithy:calibrate."
            )

    # ---- effort banner ---------------------------------------------------
    if effort:
        want = banner_for(effort)
        if not want:
            notes.append(f"WARNING: effort '{effort}' has no banner in the model registry")
        else:
            first = next((ln for ln in prompt.splitlines() if ln.strip()), "")
            if first.strip() != want:
                body = strip_banners(prompt, all_banners())
                updated["prompt"] = f"{want}\n\n{body}" if body else want
                notes.append(f"effort banner -> {effort.upper()} (role '{role}')")

    if updated == tool_input:
        return None, notes
    return updated, notes


def emit(updated: dict | None, notes: list[str]) -> None:
    if updated is None and not notes:
        return
    hook: dict = {"hookEventName": "PreToolUse"}
    if updated is not None:
        hook["updatedInput"] = updated
    if notes:
        hook["additionalContext"] = (
            f"{TAG} corrected this dispatch to match smithy config: "
            + "; ".join(notes)
            + ". Routing comes from config (routing.<role>.model/effort) — change it "
            "with /smithy:calibrate, not in the dispatch call."
        )
    print(json.dumps({"hookSpecificOutput": hook}))


def parse_check_args(argv: list[str]) -> dict:
    ti: dict = {"subagent_type": "", "prompt": ""}
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg == "--agent" and i + 1 < len(argv):
            ti["subagent_type"] = argv[i + 1]; i += 2
        elif arg == "--model" and i + 1 < len(argv):
            ti["model"] = argv[i + 1]; i += 2
        elif arg == "--prompt" and i + 1 < len(argv):
            ti["prompt"] = argv[i + 1]; i += 2
        elif arg == "--prompt-file" and i + 1 < len(argv):
            ti["prompt"] = open(argv[i + 1]).read(); i += 2
        else:
            raise SystemExit(f"route_guard.py: unknown check argument '{arg}'")
    if not ti["subagent_type"]:
        raise SystemExit("route_guard.py: check needs --agent <subagent_type>")
    return ti


def main(argv: list[str]) -> int:
    mode = argv[0] if argv else ""

    if mode == "hook":
        # Every failure below ends in a quiet exit 0: a guard that cannot
        # decide must never be the reason a dispatch dies.
        try:
            if not os.path.isdir(os.environ.get("SMITHY_MEM", "")):
                return 0  # not a smithy-managed project
            payload = json.load(sys.stdin)
            tool_input = payload.get("tool_input") or {}
            if not isinstance(tool_input, dict) or not tool_input.get("subagent_type"):
                return 0
            emit(*enforce(tool_input))
        except Exception as exc:  # noqa: BLE001 — failing open is the contract
            print(f"{TAG} inactive for this dispatch ({exc})", file=sys.stderr)
        return 0

    if mode == "check":
        tool_input = parse_check_args(argv[1:])
        updated, notes = enforce(tool_input)
        if updated is None and not notes:
            print(f"{TAG} no change — dispatch already matches config")
            return 0
        emit(updated, notes)
        return 0

    print("usage: route_guard.py hook | check --agent <type> [--model M] "
          "[--prompt P | --prompt-file F]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
