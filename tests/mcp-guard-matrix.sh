#!/usr/bin/env bash
# mcp-guard.sh test matrix. Run: bash tests/mcp-guard-matrix.sh
# Tool names are real ones from common MCP servers, so the word lists are
# tested against what agents will actually call.
set -u
G="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/mcp-guard.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
fails=0
t() { got="$(bash "$G" check "$2")"
  if [ "$got" = "$1" ]; then printf 'PASS  %-4s %s\n' "$got" "$2"
  else printf 'FAIL! want=%s got=%s  %s\n' "$1" "$got" "$2"; fails=$((fails + 1)); fi; }

echo "--- claude-mem (memory) ---"
M=mcp__plugin_claude-mem_mcp-search
t READ "${M}__search"
t READ "${M}__timeline"
t READ "${M}__get_observations"
t READ "${M}__smart_outline"
t READ "${M}__smart_search"
t READ "${M}__smart_unfold"
t READ "${M}__observation_search"
t READ "${M}__observation_context"
t READ "${M}__query_corpus"
t READ "${M}__list_corpora"
t READ "${M}__observation_generation_status"
t ASK  "${M}__observation_add"
t ASK  "${M}__observation_record_event"
t ASK  "${M}__build_corpus"
t ASK  "${M}__prime_corpus"
t ASK  "${M}__rebuild_corpus"
t ASK  "${M}__session_start_context"
t ASK  "${M}____IMPORTANT"

echo "--- docs (context7 style, kebab and camel case) ---"
t READ "mcp__context7__resolve-library-id"
t READ "mcp__context7__get-library-docs"
t READ "mcp__context7__query-docs"
t READ "mcp__context7__getLibraryDocs"

echo "--- Slack ---"
SL=mcp__claude_ai_Slack
t READ "${SL}__slack_read_channel"
t READ "${SL}__slack_read_thread"
t READ "${SL}__slack_search_public"
t READ "${SL}__slack_list_user_channels"
t READ "${SL}__slack_get_reactions"
t ASK  "${SL}__slack_send_message"
t ASK  "${SL}__slack_send_message_draft"
t ASK  "${SL}__slack_schedule_message"
t ASK  "${SL}__slack_add_reaction"
t ASK  "${SL}__slack_create_canvas"
t ASK  "${SL}__slack_update_list_record"
t ASK  "${SL}__slack_complete_file_upload"
t ASK  "${SL}__slack_get_file_upload_url"

echo "--- Notion ---"
N=mcp__claude_ai_Notion
t READ "${N}__notion-search"
t READ "${N}__notion-fetch"
t READ "${N}__notion-ai-search"
t READ "${N}__notion-get-users"
t READ "${N}__notion-query-data-sources"
t READ "${N}__notion-check-mcp-next-steps"
t ASK  "${N}__notion-create-pages"
t ASK  "${N}__notion-update-page"
t ASK  "${N}__notion-move-pages"
t ASK  "${N}__notion-duplicate-page"
t ASK  "${N}__notion-spawn-session"
t ASK  "${N}__notion-send-message-to-session"
t ASK  "${N}__notion-download-attachment"

echo "--- invoices / agreements ---"
A=mcp__claude_ai_Agree
t READ "${A}__list_invoices"
t READ "${A}__get_invoice_pdf_url"
t READ "${A}__get_revenue_stats"
t ASK  "${A}__create_invoice"
t ASK  "${A}__send_invoice"
t ASK  "${A}__mark_invoice_as_paid"
t ASK  "${A}__delete_contact"
t ASK  "${A}__create_and_send_agreement"
t ASK  "${A}__send_agreement_reminder"
t ASK  "${A}__send_test_webhook"

echo "--- docs editor / drive ---"
D=mcp__claude_ai_Claude_Docs
t READ "${D}__read"
t ASK  "${D}__query"            # a bare "query" may be SQL: asking costs one click
t READ "${D}__guide"
t ASK  "${D}__batch"
t ASK  "${D}__update"
t ASK  "${D}__create"
t ASK  "${D}__delete"
t ASK  "${D}__export"
t ASK  "mcp__claude_ai_Google_Drive__authenticate"
t ASK  "mcp__claude_ai_Google_Drive__complete_authentication"

echo "--- SQL and resolve ---"
t ASK  "mcp__postgres__query"
t ASK  "mcp__db__execute_sql"
t READ "mcp__sqlite__read_query_results"
t ASK  "mcp__github__resolve_review_thread"
t ASK  "mcp__pagerduty__resolve_incident"
t READ "mcp__context7__resolve-library-id"
t READ "${M}__query_corpus"

echo "--- other common servers ---"
t ASK  "mcp__github__create_pull_request"
t ASK  "mcp__github__merge_pull_request"
t READ "mcp__github__list_issues"
t READ "mcp__github__get_file_contents"
t READ "mcp__github__search_code"
t ASK  "mcp__filesystem__write_file"
t ASK  "mcp__filesystem__edit_file"
t ASK  "mcp__filesystem__move_file"
t READ "mcp__filesystem__read_file"
t ASK  "mcp__playwright__browser_click"
t ASK  "mcp__playwright__browser_type"
t ASK  "mcp__playwright__browser_navigate"
t READ "mcp__playwright__browser_snapshot"

echo "--- unknown verbs ask ---"
t ASK  "mcp__weird__frobnicate"
t ASK  "mcp__weird__get_or_create_user"

echo "--- hook mode ---"
h() { # h <want: ask|none> <name> <json> [project-dir]
  out="$(cd "${4:-$SCRATCH/managed}" && printf '%s' "$3" | bash "$G" hook)"
  if [ "$1" = ask ]; then echo "$out" | grep -q '"permissionDecision":"ask"' && got=ask || got=none
  else [ -z "$out" ] && got=none || got=ask; fi
  if [ "$got" = "$1" ]; then printf 'PASS  %-4s %s\n' "$got" "$2"
  else printf 'FAIL! want=%s got=%s  %s (%s)\n' "$1" "$got" "$2" "$out"; fails=$((fails + 1)); fi; }
mkdir -p "$SCRATCH/managed" "$SCRATCH/plain"
(cd "$SCRATCH/managed" && git init -q -b main && mkdir -p docs/smithy)
(cd "$SCRATCH/plain" && git init -q -b main)
unset SMITHY_MEM_DIR
h ask  "write tool in a smithy project asks" '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{}}'
h none "read tool in a smithy project says nothing" '{"tool_name":"mcp__plugin_claude-mem_mcp-search__search","tool_input":{"query":"x"}}'
h none "non-MCP tool is ignored" '{"tool_name":"Bash","tool_input":{"command":"ls"}}'
h ask  "unreadable input asks" 'not json at all'
h none "write tool outside smithy projects is left alone" '{"tool_name":"mcp__claude_ai_Slack__slack_send_message"}' "$SCRATCH/plain"
h ask  "a tool_name hidden inside tool_input cannot fool it" '{"tool_name":"mcp__claude_ai_Slack__slack_send_message","tool_input":{"tool_name":"mcp__a__search"}}'
h ask  "…in either order" '{"tool_input":{"x":{"tool_name":"mcp__a__search"}},"tool_name":"mcp__hub__call_tool"}'
out="$(cd "$SCRATCH/managed" && printf '%s' '{"tool_name":"mcp__x__send\\\"oops"}' | bash "$G" hook)"
if printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then printf 'PASS  %s\n' "hook output stays valid JSON with odd characters"; else printf 'FAIL! hook output is not valid JSON: %s\n' "$out"; fails=$((fails + 1)); fi
h none "spaces in the JSON are fine" '{ "tool_name" : "mcp__context7__get-library-docs" }'

echo
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
