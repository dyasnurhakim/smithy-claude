#!/usr/bin/env python3
"""smithy_config.py — layered config reads/writes + model-registry resolution.

Deliberately knows NOTHING about where files live: every path arrives via the
environment, set by scripts/paths.sh. That keeps one answer to "where?" (bash,
hook-safe) and one answer to "what?" (here, JSON-shaped).

Config layers, lowest precedence first:
    defaults   $SMITHY_DEFAULTS         plugin defaults, never edited per project
    global     $SMITHY_GLOBAL_CONFIG    $SMITHY_HOME/config.json  — all projects
    project    $SMITHY_PROJECT_CONFIG   <memory-dir>/config.json  — this project

Model registry, lowest precedence first:
    $SMITHY_MODELS           plugin defaults/models.json
    $SMITHY_GLOBAL_MODELS    $SMITHY_HOME/models.json — add families locally

Commands (all output is TAB-separated; warnings go to stderr):
    harness
    roles
    layers                       -> layer  path  exists
    get <dotted.key>             -> value          (exit 1 if absent everywhere)
    get-source <dotted.key>      -> layer name
    routing [<role>]             -> role  model  effort  source
    models                       -> name  tier  kind
    efforts
    set <layer> <dotted.key> <value>
"""
from __future__ import annotations

import fnmatch
import json
import os
import sys

TAB = "\t"
LAYERS = ("defaults", "global", "project")
LAYER_ENV = {
    "defaults": "SMITHY_DEFAULTS",
    "global": "SMITHY_GLOBAL_CONFIG",
    "project": "SMITHY_PROJECT_CONFIG",
}


def warn(msg: str) -> None:
    print(f"smithy-config: {msg}", file=sys.stderr)


def die(msg: str, code: int = 2):
    print(f"smithy-config: {msg}", file=sys.stderr)
    raise SystemExit(code)


def layer_path(layer: str) -> str:
    return os.environ.get(LAYER_ENV[layer], "")


def load_json(path: str, label: str) -> dict:
    """Missing file -> {} (expected for sparse layers). Malformed -> {} + a LOUD
    warning: silently ignoring it would hide that overrides stopped applying."""
    if not path or not os.path.isfile(path):
        return {}
    try:
        data = json.load(open(path))
    except Exception as exc:
        warn(f"WARNING: {path} is not valid JSON ({exc}) — ALL {label} overrides ignored")
        return {}
    if not isinstance(data, dict):
        warn(f"WARNING: {path} is not a JSON object — ALL {label} overrides ignored")
        return {}
    return data


def load_layers() -> dict[str, dict]:
    return {ly: load_json(layer_path(ly), ly) for ly in LAYERS}


def deep_merge(base: dict, over: dict) -> dict:
    out = dict(base)
    for k, v in over.items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def dig(data, dotted: str):
    """-> (found, value). Comment keys ('//...') are never addressable."""
    cur = data
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return False, None
        cur = cur[part]
    return True, cur


def lookup(layers: dict[str, dict], dotted: str):
    """-> (found, value, layer) — highest-precedence layer holding this leaf."""
    for ly in reversed(LAYERS):
        found, val = dig(layers[ly], dotted)
        if found:
            return True, val, ly
    return False, None, "none"


def render(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return ""
    if isinstance(value, (str, int, float)):
        return str(value)
    return json.dumps(value)


# ------------------------------------------------------------- registry ------
def load_registry() -> dict:
    reg = load_json(os.environ.get("SMITHY_MODELS", ""), "model-registry")
    if not reg:
        die("model registry not found or unreadable ($SMITHY_MODELS)", 1)
    overlay = load_json(os.environ.get("SMITHY_GLOBAL_MODELS", ""), "model-registry overlay")
    if overlay:
        reg = deep_merge(reg, overlay)
    return reg


def harness_conf(reg: dict, harness: str) -> dict:
    return reg.get("harnesses", {}).get(harness, {}) or {}


def matches_patterns(value: str, conf: dict) -> bool:
    return any(fnmatch.fnmatchcase(value, p) for p in conf.get("id_patterns", []))


def resolve_model(value: str, harness: str, reg: dict):
    """-> (final|None, kind). kind: native | tier | translated | pattern
                                   | foreign | invalid | inherit

    Ordered so that a name native to the ACTIVE harness always wins over a
    pattern that would also match it, and cross-family translation happens by
    TIER rather than by name — which is what keeps the registry version-proof:
    a model nobody has heard of yet still resolves via id_patterns."""
    if value == "inherit":
        return value, "inherit"

    here = harness_conf(reg, harness)
    tiers = reg.get("tiers", [])

    if value in tiers:
        final = here.get("tier_default", {}).get(value)
        return (final, "tier") if final else (None, "invalid")

    if value in here.get("models", {}):
        return value, "native"

    for other, conf in reg.get("harnesses", {}).items():
        if other == harness:
            continue
        tier = conf.get("models", {}).get(value)
        if tier:
            final = here.get("tier_default", {}).get(tier)
            return (final, "translated") if final else (None, "invalid")

    if matches_patterns(value, here):
        return value, "pattern"

    for other, conf in reg.get("harnesses", {}).items():
        if other != harness and matches_patterns(value, conf):
            return None, "foreign"

    return None, "invalid"


# -------------------------------------------------------------- routing ------
def role_list(layers: dict[str, dict]) -> list[str]:
    """Roles are whatever the DEFAULTS layer declares — adding a role is a
    defaults/config.json edit, never a code edit."""
    roles = list((layers["defaults"].get("routing") or {}).keys())
    return [r for r in roles if not r.startswith("//")]


def active_harness(layers: dict[str, dict], reg: dict) -> str:
    found, val, _ = lookup(layers, "harness")
    harness = val if found else "claude"
    if harness not in reg.get("harnesses", {}):
        known = " ".join(sorted(reg.get("harnesses", {})))
        warn(f"WARNING: unknown harness '{harness}' — using claude (known: {known})")
        harness = "claude"
    return harness


def resolve_role(role: str, layers: dict[str, dict], reg: dict, harness: str):
    """-> (model, effort, source)"""
    efforts = reg.get("efforts", [])
    raw_model, model_layer = None, "none"
    raw_effort, effort_layer = None, "none"

    for ly in reversed(LAYERS):
        f, v = dig(layers[ly], f"routing.{role}.model")
        if f and raw_model is None:
            raw_model, model_layer = v, ly
        f, v = dig(layers[ly], f"routing.{role}.effort")
        if f and raw_effort is None:
            raw_effort, effort_layer = v, ly

    if raw_effort is not None and raw_effort not in efforts:
        warn(f"invalid effort '{raw_effort}' for role '{role}' in {effort_layer} config; using default")
        raw_effort, effort_layer = None, "none"
        f, v = dig(layers["defaults"], f"routing.{role}.effort")
        if f:
            raw_effort, effort_layer = v, "defaults"

    def default_model():
        f, v = dig(layers["defaults"], f"routing.{role}.model")
        return v if f else None

    if raw_model is None:
        raw_model, model_layer = default_model(), "defaults"
    if raw_model is None:
        return None, raw_effort, "none"

    final, kind = resolve_model(str(raw_model), harness, reg)

    if kind in ("foreign", "invalid"):
        why = (f"model '{raw_model}' is not usable under harness '{harness}'"
               if kind == "foreign" else f"invalid model '{raw_model}'")
        fb_raw = default_model()
        fb, fb_kind = resolve_model(str(fb_raw), harness, reg) if fb_raw else (None, "invalid")
        if fb is None:
            die(f"{why} for role '{role}', and the default is unusable too", 1)
        warn(f"{why} for role '{role}' ({model_layer} config) — falling back to '{fb}'")
        return fb, raw_effort, "defaults(harness-fallback)"

    source = "defaults" if model_layer == "defaults" else model_layer
    if kind == "tier":
        source += "(tier)"
    elif kind == "translated":
        source += "(translated)"
    return final, raw_effort, source


# ------------------------------------------------------------- set/write -----
def parse_value(raw: str):
    try:
        return json.loads(raw)
    except Exception:
        return raw


def set_key(layer: str, dotted: str, raw: str) -> None:
    if layer == "defaults":
        die("refusing to write the plugin defaults layer — use --global or --project", 3)
    path = layer_path(layer)
    if not path:
        die(f"no path for layer '{layer}' (is paths.sh sourced?)", 3)

    value = parse_value(raw)
    layers = load_layers()

    # Compare RAW tokens against the layer below: prune only when the write
    # would be a literal no-op. Comparing RESOLVED values instead would silently
    # drop e.g. project review=opus over a defaults flagship, and calibrate's
    # verify step would then correctly refuse to call it a success.
    below = [ly for ly in LAYERS if LAYERS.index(ly) < LAYERS.index(layer)]
    inherited, inherited_found = None, False
    for ly in reversed(below):
        f, v = dig(layers[ly], dotted)
        if f:
            inherited, inherited_found = v, True
            break

    data = load_json(path, layer)
    parts = dotted.split(".")
    if inherited_found and inherited == value:
        cur = data
        chain = [cur]
        for part in parts[:-1]:
            if not isinstance(cur.get(part), dict):
                cur = None
                break
            cur = cur[part]
            chain.append(cur)
        if cur is not None and parts[-1] in cur:
            del cur[parts[-1]]
            for node, key in zip(reversed(chain[:-1]), reversed(parts[:-1])):
                if isinstance(node.get(key), dict) and not node[key]:
                    del node[key]
        print(f"pruned{TAB}{layer}{TAB}{dotted}{TAB}{render(value)}")
    else:
        cur = data
        for part in parts[:-1]:
            if not isinstance(cur.get(part), dict):
                cur[part] = {}
            cur = cur[part]
        cur[parts[-1]] = value
        print(f"set{TAB}{layer}{TAB}{dotted}{TAB}{render(value)}")

    data.setdefault("smithy_config_version",
                    layers["defaults"].get("smithy_config_version", 1))
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = f"{path}.tmp.{os.getpid()}"
    with open(tmp, "w") as fh:
        json.dump(data, fh, indent=2, sort_keys=False)
        fh.write("\n")
    os.replace(tmp, path)


# ------------------------------------------------------------------ main -----
def main(argv: list[str]) -> int:
    if not argv:
        die("usage: smithy_config.py harness|roles|layers|get|get-source|routing|models|efforts|set")
    cmd, rest = argv[0], argv[1:]

    if cmd == "layers":
        for ly in LAYERS:
            p = layer_path(ly)
            print(TAB.join([ly, p or "(unset)", "yes" if p and os.path.isfile(p) else "no"]))
        return 0

    layers = load_layers()

    if cmd == "roles":
        print(" ".join(role_list(layers)))
        return 0

    if cmd == "get":
        if len(rest) != 1:
            die("usage: get <dotted.key>")
        found, val, _ = lookup(layers, rest[0])
        if not found:
            return 1
        print(render(val))
        return 0

    if cmd == "get-source":
        if len(rest) != 1:
            die("usage: get-source <dotted.key>")
        _, _, ly = lookup(layers, rest[0])
        print(ly)
        return 0

    if cmd == "set":
        if len(rest) != 3:
            die("usage: set <global|project> <dotted.key> <value>")
        set_key(rest[0], rest[1], rest[2])
        return 0

    reg = load_registry()

    if cmd == "harness":
        print(active_harness(layers, reg))
        return 0

    if cmd == "efforts":
        print(" ".join(reg.get("efforts", [])))
        return 0

    if cmd == "models":
        harness = active_harness(layers, reg)
        conf = harness_conf(reg, harness)
        for tier in reg.get("tiers", []):
            rep = conf.get("tier_default", {}).get(tier, "")
            print(TAB.join([tier, tier, f"tier -> {rep}"]))
        for name, tier in conf.get("models", {}).items():
            print(TAB.join([name, tier, "model"]))
        print(TAB.join(["inherit", "-", "no model param at dispatch"]))
        for pat in conf.get("id_patterns", []):
            print(TAB.join([pat, "-", "pattern (any matching id, incl. future releases)"]))
        return 0

    if cmd == "routing":
        harness = active_harness(layers, reg)
        roles = role_list(layers)
        if rest:
            if rest[0] not in roles:
                die(f"unknown role '{rest[0]}' (roles: {' '.join(roles)})")
            roles = [rest[0]]
        for role in roles:
            model, effort, source = resolve_role(role, layers, reg, harness)
            print(TAB.join([role, model or "", effort or "", source]))
        return 0

    die(f"unknown command '{cmd}'")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
