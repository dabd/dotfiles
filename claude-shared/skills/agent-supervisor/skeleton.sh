#!/usr/bin/env bash
# agent-supervisor skeleton: narrative-only view of an agent transcript.
# Emits USER/ASSISTANT text and TOOL names; never tool outputs or file bodies.
set -euo pipefail

f="${1:-}"
[ -r "$f" ] || { echo "cannot read transcript: $f" >&2; exit 2; }

# Parse line by line with fromjson? so a live transcript's partial trailing
# line is skipped instead of aborting the run.
if head -20 "$f" | jq -Re 'fromjson? | select(.payload != null)' >/dev/null 2>&1; then
  # Codex rollout format
  jq -Rr '
    fromjson? | select(.type == "response_item") | .timestamp as $ts | .payload
    | if .type == "message" and .role == "user" then
        "[\($ts)] USER: \([.content[]? | .text // empty] | join(" ") | .[0:500])"
      elif .type == "message" and .role == "assistant" then
        "[\($ts)] ASSISTANT: \([.content[]? | .text // empty] | join(" ") | .[0:500])"
      elif .type == "function_call" or .type == "custom_tool_call" then
        "[\($ts)] TOOL: \(.name)"
      else empty end
    | select(test(": $") | not)
  ' "$f"
else
  # Claude Code format
  jq -Rr '
    fromjson? | select(.type == "user" or .type == "assistant") | .timestamp as $ts
    | if .type == "user" then
        (.message.content
         | if type == "string" then .
           else ([.[]? | select(.type == "text") | .text] | join(" ")) end
         | select(length > 0)
         | "[\($ts)] USER: \(.[0:500])")
      else
        # single ordered pass, so narration and tool calls stay interleaved
        (.message.content[]?
         | if .type == "text" then "[\($ts)] ASSISTANT: \(.text[0:500])"
           elif .type == "tool_use" then "[\($ts)] TOOL: \(.name)"
           else empty end)
      end
  ' "$f"
fi
