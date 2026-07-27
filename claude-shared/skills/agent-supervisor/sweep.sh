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
  if printf '%s\n' "$tail40" | grep -qE '^╭|│ >|\? for shortcuts|⏎ send'; then
    echo idle; return
  fi
  echo unknown
}

# kind_from_command <pane_current_command> -> claude|codex|shell|other
kind_from_command() {
  case "$1" in
    claude|node) echo claude ;;
    codex)       echo codex ;;
    zsh|bash|sh|fish) echo shell ;;
    *)           echo other ;;
  esac
}

# CLI dispatch only when executed directly, so that sourcing this file to reuse
# the functions above cannot exit the calling shell.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
  if [ "${1:-}" = "--classify" ]; then
    classify_pane "$2" "$3"
    exit 0
  fi

  command -v tmux >/dev/null || { echo "tmux not found" >&2; exit 2; }
  tmux info >/dev/null 2>&1 || { echo "tmux server not running" >&2; exit 2; }

  if [ $# -gt 0 ]; then
    sessions="$*"
    for s in $sessions; do
      tmux has-session -t "=$s" 2>/dev/null || { echo "no such session: $s" >&2; exit 2; }
    done
  else
    sessions=$(tmux list-sessions -F '#{session_name}')
  fi

  now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  session_jsons=""

  for s in $sessions; do
    sdir="$STATE_ROOT/$s"
    mkdir -p "$sdir"
    window_jsons=""

    # one line per window: index<TAB>name<TAB>pane_current_command
    while IFS=$(printf '\t') read -r idx name cmd; do
      kind=$(kind_from_command "$cmd")
      snap="$sdir/win-$idx.txt"
      cnt="$sdir/win-$idx.count"
      new=$(mktemp)
      tmux capture-pane -p -t "=$s:$idx" -S "-$TAIL_LINES" > "$new" 2>/dev/null || : > "$new"

      changed=true
      if [ -f "$snap" ] && cmp -s "$snap" "$new"; then changed=false; fi
      if [ "$changed" = true ]; then
        echo 0 > "$cnt"
      else
        c=$(cat "$cnt" 2>/dev/null || echo 0); echo $((c+1)) > "$cnt"
      fi
      mv "$new" "$snap"
      unchanged=$(cat "$cnt")

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
  done

  printf '%s' "$session_jsons" | jq -s --arg now "$now" '{generated_at:$now,sessions:.}'
fi
