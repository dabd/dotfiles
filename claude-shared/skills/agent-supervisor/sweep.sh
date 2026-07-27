#!/usr/bin/env bash
# agent-supervisor sweep: classify tmux panes running coding agents.
# Read-only: never sends keys to any session.
set -euo pipefail

STATE_ROOT="${AGENT_SUPERVISOR_STATE:-$HOME/.local/state/agent-supervisor}"
TAIL_LINES=200
REPORT_TAIL=15
STUCK_SWEEPS=3

# classify_pane <file> <kind> -> waiting_permission|working|idle|exited|unknown
classify_pane() {
  local f=$1 kind=$2 tail40
  # No readable capture means no evidence: report unknown rather than letting
  # grep complain on stderr or inferring a state from an empty read.
  [ -r "$f" ] || { echo unknown; return; }
  tail40=$(grep -v '^[[:space:]]*$' "$f" | tail -40 || true)
  if printf '%s\n' "$tail40" | grep -qiE 'do you want to proceed|allow command\?|don.t ask again|tell (claude|codex) what to do'; then
    echo waiting_permission; return
  fi
  if printf '%s\n' "$tail40" | grep -qiE 'esc to interrupt|interrupt.*esc'; then
    echo working; return
  fi
  if [ "$kind" = "shell" ]; then echo exited; return; fi
  # Idle means the agent is showing its input chrome and waiting for a human.
  # The first four patterns are the boxed prompt; the rest are the flat chrome
  # real Claude Code and Codex panes show (bare prompt caret, context meter,
  # mode line). The shell short-circuit above runs first on purpose, so a plain
  # zsh prompt caret stays `exited` rather than looking like an idle agent.
  if printf '%s\n' "$tail40" | grep -qE '^╭|│ >|\? for shortcuts|⏎ send|^❯[[:space:]]*$|% ctx ·|Context [0-9]+% used|^› |mode on.*(shift\+tab|← for agents)'; then
    echo idle; return
  fi
  echo unknown
}

# normalize_for_diff <file> -> the file's content minus volatile status lines.
# A live agent status line carries a ticking elapsed timer and token count
# ("esc to interrupt / 42s / 12.1k tokens"), so a byte-exact compare of two
# captures always differs and no window would ever look unchanged. Dropping
# those lines makes "only the spinner moved" count as unchanged, which is what
# the stuck detector and the quiet rule need. The stored snapshot stays raw:
# classification and the reported tail still see the real pane.
normalize_for_diff() {
  grep -viE 'esc to interrupt|interrupt.*esc' "$1" || true
}

# kind_from_command <pane_current_command> -> claude|codex|shell|other
# Fallback only, for panes whose content shows no agent chrome. `node` maps to
# other, not claude: Codex CLI runs as node, so the command name proves nothing.
kind_from_command() {
  case "$1" in
    claude) echo claude ;;
    codex)  echo codex ;;
    zsh|bash|sh|fish) echo shell ;;
    *)      echo other ;;
  esac
}

# detect_kind <file> <pane_current_command> -> claude|codex|shell|other
# Content first, because pane_current_command lies about real agents: Claude Code
# reports its own version string (e.g. 2.1.220, different every release) and
# Codex CLI reports node. The pane chrome is the reliable signal; the command
# name is only the fallback for panes with no chrome at all.
detect_kind() {
  local f=$1 cmd=$2
  if [ -r "$f" ]; then
    if grep -qiF -e '% ctx ·' -e 'shift+tab to cycle' "$f"; then echo claude; return; fi
    if grep -qE 'Context [0-9]+% used|^› ' "$f"; then echo codex; return; fi
  fi
  kind_from_command "$cmd"
}

# CLI dispatch only when executed directly, so that sourcing this file to reuse
# the functions above cannot exit the calling shell.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  if [ "${1:-}" = "--classify" ]; then
    classify_pane "$2" "$3"
    exit 0
  fi

  if [ "${1:-}" = "--detect-kind" ]; then
    detect_kind "$2" "$3"
    exit 0
  fi

  command -v tmux >/dev/null || { echo "tmux not found" >&2; exit 2; }
  tmux info >/dev/null 2>&1 || { echo "tmux server not running" >&2; exit 2; }

  # Session names may contain spaces, so the list is newline-separated
  # throughout and never word-split.
  if [ $# -gt 0 ]; then
    for s in "$@"; do
      tmux has-session -t "=$s" 2>/dev/null || { echo "no such session: $s" >&2; exit 2; }
    done
    sessions=$(printf '%s\n' "$@")
  else
    sessions=$(tmux list-sessions -F '#{session_name}')
  fi

  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  session_jsons=""

  while IFS= read -r s; do
    [ -n "$s" ] || continue
    sdir="$STATE_ROOT/$s"
    mkdir -p "$sdir"
    window_jsons=""

    # one line per window: index<TAB>name<TAB>pane_current_command
    while IFS=$(printf '\t') read -r idx name cmd; do
      snap="$sdir/win-$idx.txt"
      cnt="$sdir/win-$idx.count"
      new=$(mktemp)
      tmux capture-pane -p -t "=$s:$idx" -S "-$TAIL_LINES" > "$new" 2>/dev/null || : > "$new"

      changed=true
      if [ -f "$snap" ] && cmp -s <(normalize_for_diff "$snap") <(normalize_for_diff "$new"); then
        changed=false
      fi
      if [ "$changed" = true ]; then
        echo 0 > "$cnt"
      else
        c=$(cat "$cnt" 2>/dev/null || echo 0); echo $((c+1)) > "$cnt"
      fi
      mv "$new" "$snap"
      unchanged=$(cat "$cnt")

      # Detect the kind after the mv, so it reads this sweep's capture rather
      # than the previous one (or nothing at all on the first sweep).
      kind=$(detect_kind "$snap" "$cmd")
      state=$(classify_pane "$snap" "$kind")
      stuck=false
      [ "$state" = "working" ] && [ "$unchanged" -ge "$STUCK_SWEEPS" ] && stuck=true

      want_tail=false
      case "$state" in waiting_permission|exited|unknown) want_tail=true ;; esac
      [ "$changed" = true ] && want_tail=true
      [ "$stuck" = true ] && want_tail=true
      # quiet rule: unchanged working/idle windows stay silent
      if [ "$changed" = false ] && [ "$stuck" = false ]; then
        case "$state" in working|idle) want_tail=false ;; esac
      fi

      if [ "$want_tail" = true ]; then
        tail_json=$({ grep -v '^[[:space:]]*$' "$snap" || true; } | tail -"$REPORT_TAIL" | jq -R . | jq -s .)
      else
        tail_json='[]'
      fi

      w=$(jq -n \
        --argjson index "$idx" --arg name "$name" --arg agent "$kind" \
        --arg state "$state" --argjson changed "$changed" \
        --argjson unchanged "$unchanged" --argjson stuck "$stuck" \
        --argjson tail "$tail_json" \
        '{index:$index,name:$name,agent:$agent,state:$state,changed:$changed,
          unchanged_sweeps:$unchanged,possibly_stuck:$stuck,tail:$tail}')
      window_jsons="$window_jsons$w"
    done <<EOF
$(tmux list-windows -t "=$s" -F "#{window_index}$(printf '\t')#{window_name}$(printf '\t')#{pane_current_command}")
EOF

    # prune state for windows that no longer exist
    live=$(tmux list-windows -t "=$s" -F '#{window_index}')
    for f in "$sdir"/win-*.txt; do
      [ -e "$f" ] || continue
      i=$(basename "$f" .txt); i=${i#win-}
      echo "$live" | grep -qx "$i" || rm -f "$sdir/win-$i.txt" "$sdir/win-$i.count"
    done

    sj=$(printf '%s' "$window_jsons" | jq -s --arg session "$s" '{session:$session,windows:.}')
    session_jsons="$session_jsons$sj"
  done <<SESSIONS
$sessions
SESSIONS

  printf '%s' "$session_jsons" | jq -s --arg now "$now" '{generated_at:$now,sessions:.}'
fi
