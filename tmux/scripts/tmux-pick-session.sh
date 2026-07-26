#!/usr/bin/env bash
# MRU session picker. Lists sessions sorted by last-attached (most recent
# first), current session included (it sorts to the top), with a live preview
# of each session's active pane. Switches the client to the chosen session.
set -euo pipefail

# Sort by last-attached epoch, then strip the epoch key, keeping the full
# session name verbatim (names may contain spaces).
sel="$(
  tmux list-sessions -F '#{session_last_attached} #{session_name}' \
    | sort -rn \
    | sed 's/^[0-9]* //' \
    | fzf --reverse --no-multi \
        --header='switch session (MRU)' \
        --preview='tmux capture-pane -ep -t {}: 2>/dev/null | tail -n 60' \
        --preview-window='right,60%,wrap'
)"

[ -n "${sel:-}" ] && tmux switch-client -t "$sel"
