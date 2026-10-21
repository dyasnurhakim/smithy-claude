#!/usr/bin/env bash
# mcp-guard.sh — MCP tools: reading is free, changing things asks first.
#
#   mcp-guard.sh hook            PreToolUse hook for every "mcp__.*" call.
#                                Reads the hook JSON on stdin.
#   mcp-guard.sh check <tool>    Same decision from the command line.
#                                Prints READ or ASK.
#
# What it does, in one picture:
#
#   mcp__plugin_claude-mem_mcp-search__search      ──▶ READ  (say nothing; normal
#   mcp__context7__get-library-docs                ──▶ READ   permissions apply)
#   mcp__claude_ai_Slack__slack_send_message       ──▶ ASK   (a person must say yes)
#   mcp__some_server__frobnicate   (unknown verb)  ──▶ ASK
#
# Why: smithy agents may use MCP tools (memory, code graph, docs) to look
# things up. Looking up is safe. Sending, creating, updating or deleting is
# not — it reaches other people or changes data. So any tool whose name has a
# "change" word, or no known "read" word, makes Claude Code ask the user first.
# This holds even when the user's own rules name the tool: naming a tool says
# "you may use it", not "you may change things with it without asking".
#
# How it decides (tool name = the part after the last "__"):
#   1. split the name into words ("slack_send_message" → slack send message);
#   2. any CHANGE word            → ASK (checked first, so "get_or_create" asks);
#   3. else any READ word         → READ;
#   4. else (nothing known)       → ASK.
#
# Allowlist: config key mcp_guard.read_only_tools = a list of FULL tool names
# (e.g. "mcp__mysql-demo__mysql_query") that the user vouches are read-only,
# such as a SQL tool whose server login cannot write. A listed tool → READ,
# before any rule above. Exact match only: a short name, or the same tool on
# another server, still asks. The highest config layer that sets the list wins
# (lists are not merged). Broken config or no python3 → no list → the rules.
#
# Safety direction: when unsure, ASK. A wrong ASK costs one click; a wrong
# READ could post a message. The hook never says "allow" — READ means "add no
# rule of my own", so the user's normal permission settings still decide.
#
# Hooks cannot tell the main session from a subagent, so this applies to both,
# but only in projects smithy manages (its memory folder exists) — the same
# scope as guard.sh. Claude Code only; Codex runs no hooks (see harness.md).
set -u

# Path lookup stays pure bash (same as guard.sh). Only the JSON and config
# read below uses python3, once per MCP call.
SMITHY_PATHS_FAST=1
# shellcheck source=./paths.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/paths.sh"

CHANGE_WORDS=" create add update set delete del remove rm send post put patch upload write
  edit modify mark move rename duplicate copy archive insert replace merge publish schedule
  spawn stop start complete build prime rebuild reprime record apply run exec execute trigger
  approve close reopen assign unassign invite revoke grant cancel reset enable disable convert
  import batch upsert save commit push deploy drop truncate clear purge sync submit reply resolve
  comment react pin unpin star unstar subscribe unsubscribe lock unlock restore transfer pay
  refund charge book reserve order install uninstall configure authorize "
READ_WORDS=" get list read search query fetch find lookup describe show view count
  outline unfold timeline explain analyze inspect diff status info guide help docs check
  preview browse scan stat stats peek glance context snapshot screenshot "
# Flatten to one line with single spaces so a plain *" word "* match works.
# shellcheck disable=SC2086
CHANGE_WORDS=" $(echo $CHANGE_WORDS) "
# shellcheck disable=SC2086
READ_WORDS=" $(echo $READ_WORDS) "

# decide <full tool name> → prints READ or ASK
decide() {
  local name="$1" short words w
  short="${name##*__}"
  # camelCase → camel Case, then every separator → space, then lower case.
  words="$(printf '%s' "$short" | sed 's/\([a-z0-9]\)\([A-Z]\)/\1 \2/g' | tr '_.:/-' '     ' | tr '[:upper:]' '[:lower:]')"
  # Special cases the word lists cannot express:
  #   a tool named just "query", or anything with "sql" in it, can run SQL
  #   that writes (UPDATE, DROP…) → ASK;
  #   "resolve" usually closes something (a thread, an incident) → a change
  #   word, except the docs lookup "resolve-library-id".
  case "$short" in
    query|*[Ss][Qq][Ll]*) echo ASK; return ;;
    resolve-library-id|resolve_library_id|resolveLibraryId) echo READ; return ;;
  esac
  for w in $words; do
    case "$CHANGE_WORDS" in *" $w "*) echo ASK; return ;; esac
  done
  for w in $words; do
    case "$READ_WORDS" in *" $w "*) echo READ; return ;; esac
  done
  echo ASK
}

# One python3 call: the tool name (argv[1], else the TOP-LEVEL "tool_name" of
# the hook JSON on stdin), then a TAB and "listed" when the config allowlist
# names it exactly. A real JSON parse: a text search could be fooled by a
# "tool_name" key inside tool_input (which the model writes).
READ_TOOL_PY='import json, os, sys
try:
    if len(sys.argv) > 1:
        t = sys.argv[1]
    else:
        d = json.load(sys.stdin)
        t = d.get("tool_name", "") if isinstance(d, dict) else ""
    t = t if isinstance(t, str) else ""
except Exception:
    t = ""
listed = False
if t:
    try:
        sys.path.insert(0, os.environ["SMITHY_LIB_DIR"])
        import smithy_config as c
        found, val, _ = c.lookup(c.load_layers(), "mcp_guard.read_only_tools")
        listed = found and isinstance(val, list) and t in val
    except Exception:
        pass
print(t + ("\tlisted" if listed else ""))'

# read_tool [<tool>] → "<tool>" or "<tool><TAB>listed"; empty when unreadable.
read_tool() {
  SMITHY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib" \
  SMITHY_DEFAULTS="$SMITHY_DEFAULTS" SMITHY_GLOBAL_CONFIG="$SMITHY_GLOBAL_CONFIG" \
  SMITHY_PROJECT_CONFIG="$SMITHY_PROJECT_CONFIG" \
    python3 -c "$READ_TOOL_PY" "$@" 2>/dev/null
}

ask_json() { # ask_json <reason>
  local reason="${1//\\/\\\\}"   # \ → \\  (keep the JSON valid)
  reason="${reason//\"/\\\"}"         # " → \"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$reason"
}

case "${1:-}" in
  hook)
    input="$(cat 2>/dev/null)" || input=""
    # Not a smithy project → stay out of the way entirely.
    [ -d "$SMITHY_MEM" ] || exit 0
    # No python3, or broken JSON → empty → ASK (the safe side).
    line="$(printf '%s' "$input" | read_tool)" || line=""
    tool="${line%%$'\t'*}"
    if [ -z "$tool" ]; then
      ask_json "smithy mcp-guard could not read the tool name — confirm this MCP call."
      exit 0
    fi
    case "$tool" in mcp__*) ;; *) exit 0 ;; esac
    [ "$line" = "$tool"$'\t'listed ] && exit 0
    if [ "$(decide "$tool")" = ASK ]; then
      ask_json "smithy: '$tool' may change something outside this repo (send, create, update or delete). Confirm first. If it only reads, list it in mcp_guard.read_only_tools."
    fi
    exit 0
    ;;
  check)
    [ $# -eq 2 ] || { echo "usage: mcp-guard.sh check <tool_name>" >&2; exit 2; }
    if [ "$(read_tool "$2")" = "$2"$'\t'listed ]; then echo READ; else decide "$2"; fi
    ;;
  ""|-h|--help)
    sed -n '2,42p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    [ -n "${1:-}" ] || exit 2 ;;
  *)
    echo "mcp-guard.sh: unknown command '$1' (try --help)" >&2; exit 2 ;;
esac
