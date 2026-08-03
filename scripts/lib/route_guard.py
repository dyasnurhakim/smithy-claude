#!/usr/bin/env python3
"""route_guard.py — make smithy's model/effort routing DETERMINISTIC.

`references/dispatch.md` §1 asks the controller to pass the routed model as the
subagent tool's `model` parameter and to prepend the routed effort banner to
the prompt. Those are prompt rules, and prompt rules drift: the parameter gets
omitted (the subagent then silently inherits the session model), a cheaper tier
gets picked by intuition ("this task is simple"), or the banner is forgotten or
carries the wrong level. Nothing downstream notices, because a subagent has no
way to know what it was *supposed* to run as.

This is the enforcement half — the routing counterpart to guard.sh. It runs as
a PreToolUse hook on subagent dispatch and REWRITES the call to match config
rather than rejecting it: correcting costs nothing, denying costs a turn to
arrive at the same place.

Contract with the harness (verified against Claude Code 2.1.220):

    {"hookSpecificOutput": {"hookEventName": "PreToolUse",
                            "updatedInput":      {...whole tool_input...},
                            "additionalContext": "..."}}

Three things about that contract drive the design here:

  * `updatedInput` REPLACES tool_input wholesale — it is not a patch. So we
    copy the original and mutate the copy; unknown/future keys ride along.
  * It is validated against the tool's own schema, and a failure makes the
    harness DISCARD the entire hook output. An un-dispatchable model value is
    therefore reported, never injected — injecting it would silently take the
    banner fix down with it.
  * We deliberately emit no `permissionDecision`. "allow" would short-circuit
    the user's own permission rules for subagent dispatch; this hook's job is
    routing, not authorization.

Fail-open everywhere: a broken guard must never break a dispatch.
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

# Plugin hooks only run under Claude Code (references/harness.md — under Codex
# CLI dispatch.md §1 stays advisory), so reaching this code proves the running
# harness. A config that names a DIFFERENT harness is therefore describing
# models this tool cannot accept: `sol` would fail updatedInput validation and
# take the banner fix down with it. Warn instead of injecting.
HOOK_HARNESS = "claude"

# The five dispatchable smithy agents -> their routing role (dispatch.md's
# agent table). research/planning/mechanical have no agent — the controller
# does that work inline, so there is no dispatch to police.
AGENT_ROLES = {
    "forger": "implementation",
    "jigsmith": "implementation",
    "inspector": "review",
    "annealer": "debugging",
    "temperer": "testing",
}

# Escape hatch: a brief may pin a different role explicitly (e.g. dispatching a
# forger for mechanical work). Anything else is drift, not intent.
ROLE_OVERRIDE_RE = re.compile(r"^[ \t]*smithy-role:[ \t]*([A-Za-z][A-Za-z0-9_-]*)[ \t]*$", re.M)

# Generic banner shape, so a stale banner is recognised even after the registry
# text is retuned. Exact registry strings are stripped too (see strip_banners).
BANNER_LINE_RE = re.compile(r"^[ \t]*Effort:[ \t]*[A-Z]+\b.*(?:\r?\n)?", re.M)


def cfg(*args: str) -> list[list[str]]:
    """Run the config helper and return its TAB-separated rows.

    The helper owns config-layer precedence and registry merging; duplicating
    either here is how the two would drift apart."""
    out = subprocess.run(
        [sys.executable, CONFIG_LIB, *args],
        capture_output=True, text=True, timeout=TIMEOUT,
    )
    if out.returncode != 0:
        raise RuntimeError(f"smithy_config.py {' '.join(args)} failed: {out.stderr.strip()}")
    return [line.split("\t") for line in out.stdout.splitlines() if line]


def agent_role(subagent_type: str, prompt: str) -> str | None:
    """-> routing role, or None when this dispatch is none of our business."""
    name = (subagent_type or "").strip()
    if name.startswith("smithy:"):
        name = name[len("smithy:"):]
    elif ":" in name:
        return None  # another plugin's agent that happens to share a name
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
    """Model values this harness can actually put in the tool's `model` field.

    Read from the registry (kind == "model"), never hardcoded — that is what
    lets a new release land as a data edit. Tiers and id_patterns are excluded
    on purpose: `flagship` is a config value, not a dispatch value, and a
    pattern-matched raw id may fail the tool's own enum."""
    return {row[0] for row in cfg("models") if len(row) > 2 and row[2] == "model"}


def banner_for(effort: str) -> str:
    for row in cfg("banners", effort):
        if row[0] == effort:
            return row[1] if len(row) > 1 else ""
    return ""


def all_banners() -> list[str]:
    return [row[1] for row in cfg("banners") if len(row) > 1 and row[1]]


def strip_banners(prompt: str, known: list[str]) -> str:
    """Remove every effort banner from a prompt — the exact registry strings
    and anything shaped like a banner. A stale banner further down the prompt
    is the same defect as a wrong one at the top, so position is not trusted."""
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
                f"under {HOOK_HARNESS} — so '{model}' is not a dispatch value here and "
                f"was NOT injected. Set the harness with /smithy:calibrate."
            )
        elif model in dispatchable_models():
            if have != model:
                updated["model"] = model
                notes.append(f"model {have or 'unset'} -> {model} (role '{role}')")
        elif have != model:
            # Not injectable: it would fail updatedInput schema validation and
            # take the banner fix down with it. Report instead.
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
            + ". Routing is config-driven (routing.<role>.model/effort) — change it "
            "with /smithy:calibrate, not at dispatch."
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
        # Every failure path below is a silent exit 0: a guard that cannot
        # decide must not be the reason a dispatch dies.
        try:
            if not os.path.isdir(os.environ.get("SMITHY_MEM", "")):
                return 0  # not a smithy-managed project
            payload = json.load(sys.stdin)
            tool_input = payload.get("tool_input") or {}
            if not isinstance(tool_input, dict) or not tool_input.get("subagent_type"):
                return 0
            emit(*enforce(tool_input))
        except Exception as exc:  # noqa: BLE001 — fail-open is the contract
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
