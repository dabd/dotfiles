#!/usr/bin/env bash
# PreToolUse hook (Edit|Write): rewrite unicode punctuation to ASCII in the
# text an agent is about to write. Em/en dashes become hyphens, curly quotes
# become straight quotes, ellipsis becomes three dots.
#
# The patterns are backslash-u escapes (jq resolves them), not literal
# glyphs, so this file stays pure ASCII and survives being edited on a
# machine where the hook is itself active.
#
# Contract: silence means pass-through. When a rewrite is needed, emit
# hookSpecificOutput.updatedInput with the normalized field. Never blocks.

command -v jq >/dev/null 2>&1 || exit 0

jq -c '
  (if .tool_name == "Write" then "content"
   elif .tool_name == "Edit" then "new_string"
   else null end) as $field
  | if $field == null or (.tool_input[$field] // "") == "" then empty
    else
      (.tool_input[$field]
       | gsub("\u2014"; "-") | gsub("\u2013"; "-")
       | gsub("\u2018"; "'\''") | gsub("\u2019"; "'\''")
       | gsub("\u201C"; "\"") | gsub("\u201D"; "\"")
       | gsub("\u2026"; "...")) as $clean
      | if $clean == .tool_input[$field] then empty
        else {hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "allow",
                updatedInput: (.tool_input + {($field): $clean})}}
        end
    end
' 2>/dev/null || exit 0
