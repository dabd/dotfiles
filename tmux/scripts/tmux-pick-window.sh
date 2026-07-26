#!/usr/bin/env bash
# MRU window picker within the current session. Sorts windows by @lf, a
# monotonic focus counter stamped natively by the session-window-changed hook
# (attention order). Most recent first, current window included (sorts to the
# top), with a live preview.
set -euo pipefail

session="$(tmux display-message -p '#{session_name}')"

# Emit: <sortkey> <index> <name>. @lf is a small monotonic focus counter;
# windows never focused since the hook installed fall back to 0 so they sink
# to the bottom (don't mix in window_activity - its epoch scale would wrongly
# float never-focused windows to the top). After sorting, strip the sort key,
# leaving "<index> <name>" (name may contain spaces; only the index is parsed).
sel="$(
  tmux list-windows -t "$session" \
      -F '#{?@lf,#{@lf},0} #{window_index} #{window_name}' \
    | sort -rn \
    | sed 's/^[0-9]* //' \
    | fzf --reverse --no-multi \
        --header="switch window in $session (MRU)" \
        --preview='tmux capture-pane -ep -t '"$session"':{1} 2>/dev/null | tail -n 60' \
        --preview-window='right,60%,wrap'
)"

# The window index is the first whitespace-delimited field of the selection.
idx="${sel%% *}"
[ -n "${idx:-}" ] && tmux select-window -t "$session:$idx"
