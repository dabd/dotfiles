#!/bin/bash
# Claude Code status line. Reads the session JSON on stdin and prints one
# colored line: dir . git:(branch) . Model . effort . N% ctx . provider . $cost
# Mirrors the robbyrussell PS1 (cyan dir, blue/red git) then adds session info.
input=$(cat)

j() { printf '%s' "$input" | jq -r "$1 // empty" 2>/dev/null; }

cwd=$(j '.workspace.current_dir'); [ -z "$cwd" ] && cwd=$(j '.cwd')
[ -z "$cwd" ] && cwd=$(pwd)
dir=$(basename "$cwd")
model=$(j '.model.display_name')
# Only present when the model supports reasoning effort, so an empty value is
# a fact about the model rather than a missing field.
effort=$(j '.effort.level')
ctx=$(j '.context_window.used_percentage')
cost=$(j '.cost.total_cost_usd')

# One word naming what is actually serving and billing these tokens. Each mode
# in ~/.zshrc has a distinct name, so the config dir only needs to break the tie
# between the two OAuth cases. Order matters: Bedrock wins over a base URL, and
# a non-Anthropic base URL wins over a bare API key.
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"

if [ "$CLAUDE_CODE_USE_BEDROCK" = "1" ]; then
  prov="bedrock"
elif [ -n "$ANTHROPIC_BASE_URL" ] &&
     ! printf '%s' "$ANTHROPIC_BASE_URL" | grep -q 'api\.anthropic\.com'; then
  prov=$(printf '%s' "$ANTHROPIC_BASE_URL" |
         sed -E 's#^https?://(api\.)?([^./]+).*#\2#')
elif [ -n "$ANTHROPIC_API_KEY" ] || [ -n "$ANTHROPIC_AUTH_TOKEN" ]; then
  prov="api"
else
  # Plain OAuth. A work config dir means an enterprise seat, personal means Max.
  case "$cfg" in *-personal) prov="personal" ;; *) prov="enterprise" ;; esac
fi

RESET='\033[0m'; CYAN='\033[36m'; SEP='\033[90m'
GREEN='\033[32m'; YELLOW='\033[33m'; RED='\033[31m'; MODEL='\033[37m'
MAGENTA='\033[35m'
sep=" ${SEP}\xc2\xb7${RESET} "

out=""
add() { [ -z "$out" ] && out="$1" || out="${out}${sep}$1"; }

# current directory (cyan), like the robbyrussell %c
add "${CYAN}${dir}${RESET}"

# git branch (blue with red name), only inside a repo
branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
[ -n "$branch" ] && add "\033[1;34mgit:(\033[31m${branch}\033[34m)${RESET}"

# model, then reasoning effort as its own segment in the same white, since it is
# an attribute of the model rather than a separate axis like the provider
[ -n "$model" ] && add "${MODEL}${model}${RESET}"
[ -n "$effort" ] && add "${MODEL}${effort}${RESET}"

# context-window usage: green < 50, yellow < 80, red >= 80
if [ -n "$ctx" ]; then
  pct=$(printf '%.0f' "$ctx" 2>/dev/null)
  col=$GREEN
  if awk "BEGIN{exit !($ctx>=80)}"; then col=$RED
  elif awk "BEGIN{exit !($ctx>=50)}"; then col=$YELLOW
  fi
  add "${col}${pct}% ctx${RESET}"
fi

# Colour carries the axis the word does not: yellow and red mean tokens are
# metered per use, magenta means they draw against a seat or plan.
case "$prov" in
  bedrock)             pcol=$YELLOW ;;
  api)                 pcol=$RED ;;
  personal|enterprise) pcol=$MAGENTA ;;
  *)                   pcol=$RED ;;
esac
add "${pcol}${prov}${RESET}"

# Session cost, which Claude Code derives from Anthropic list pricing. That is
# roughly right on Bedrock, notional against plan limits on a subscription, and
# meaningless on a third-party endpoint serving a different model, so drop it.
if [ -n "$cost" ]; then
  c=$(printf '%.2f' "$cost")
  case "$prov" in
    bedrock)             add "${YELLOW}~\$${c}${RESET}" ;;
    api)                 add "${GREEN}\$${c}${RESET}" ;;
    personal|enterprise) add "${SEP}~\$${c}${RESET}" ;;
    *)                   : ;;
  esac
fi

printf '%b\n' "$out"
exit 0
