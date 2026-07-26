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

if [ "${1:-}" = "--classify" ]; then
  classify_pane "$2" "$3"
  exit 0
fi

echo "sweep mode not implemented yet" >&2
exit 64
