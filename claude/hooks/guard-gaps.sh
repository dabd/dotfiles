#!/usr/bin/env bash
# Small PreToolUse guard for destructive forms CC Safety Net v1.0.6 allows.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "Blocked: jq missing (guard-gaps.sh cannot inspect the command)" >&2
  exit 2
fi

CMD=$(jq -r '.tool_input.command // ""')
[ -z "$CMD" ] && exit 0

if printf '%s' "$CMD" | grep -qiE '(^|[;&|]|&&|\|\|)[[:space:]]*git[[:space:]]+checkout[[:space:]]+\.[[:space:]]*$'; then
  echo "Blocked: git checkout . discards all unstaged changes. Use git stash if you must." >&2
  exit 2
fi

if printf '%s' "$CMD" | grep -qE ':\(\)[[:space:]]*\{.*:\|:.*\}'; then
  echo "Blocked: fork bomb." >&2
  exit 2
fi

exit 0
