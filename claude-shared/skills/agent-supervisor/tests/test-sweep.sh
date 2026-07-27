#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
SWEEP=../sweep.sh
SESSION=agsup-test
export AGENT_SUPERVISOR_STATE=$(mktemp -d)
pass=0; fail=0
check() { # desc jq-filter expected report
  got=$(printf '%s' "$4" | jq -r "$2")
  if [ "$got" = "$3" ]; then pass=$((pass+1));
  else echo "FAIL: $1 expected [$3] got [$got]"; fail=$((fail+1)); fi
}

tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -x 80 -y 24 -n win0 \
  'printf "✳ Testing... (esc to interrupt · 1s)\n"; sleep 300'
tmux new-window -t "$SESSION" -n win1 \
  'printf "Do you want to proceed?\n❯ 1. Yes\n"; sleep 300'
# win2 redraws a status line carrying a ticking elapsed timer, the way a live
# agent does: every capture differs byte for byte while nothing real moved.
tmux new-window -t "$SESSION" -n win2 \
  'i=0; while :; do printf "\033[2J\033[H✳ Testing... (esc to interrupt · %ss)\n" $i; i=$((i+1)); sleep 1; done'
# win3 renders real (sanitized) Claude Code idle chrome, so the sweep has to
# reach agent=claude from content alone: pane_current_command here is `sleep`,
# and for a real agent it would be a version string.
tmux new-window -t "$SESSION" -n win3 -c "$PWD" \
  'cat fixtures/claude-idle-real.txt; sleep 300'
sleep 1

r1=$(bash "$SWEEP" "$SESSION")
check "chrome pane detected as claude" '.sessions[0].windows[3].agent' claude "$r1"
check "chrome pane idle"               '.sessions[0].windows[3].state' idle "$r1"
check "win0 working"       '.sessions[0].windows[0].state' working "$r1"
check "win1 permission"    '.sessions[0].windows[1].state' waiting_permission "$r1"
check "first sweep changed" '.sessions[0].windows[0].changed' true "$r1"
check "first sweep has tail" '.sessions[0].windows[0].tail | length > 0' true "$r1"
check "session name"       '.sessions[0].session' "$SESSION" "$r1"
check "ticker working"     '.sessions[0].windows[2].state' working "$r1"
check "ticker first sweep changed" '.sessions[0].windows[2].changed' true "$r1"

sleep 2
r2=$(bash "$SWEEP" "$SESSION")
check "ticker unchanged despite timer" '.sessions[0].windows[2].changed' false "$r2"
check "ticker unchanged counter"       '.sessions[0].windows[2].unchanged_sweeps' 1 "$r2"
check "second sweep unchanged" '.sessions[0].windows[0].changed' false "$r2"
check "unchanged counter"      '.sessions[0].windows[0].unchanged_sweeps' 1 "$r2"
check "quiet unchanged working tail" '.sessions[0].windows[0].tail | length' 0 "$r2"

r3=$(bash "$SWEEP" "$SESSION"); r4=$(bash "$SWEEP" "$SESSION")
check "stuck after 3 unchanged" '.sessions[0].windows[0].possibly_stuck' true "$r4"
check "ticker stuck after 3 unchanged" '.sessions[0].windows[2].possibly_stuck' true "$r4"

bash "$SWEEP" no-such-session >/dev/null 2>&1
[ $? -eq 2 ] && pass=$((pass+1)) || { echo "FAIL: bad session exit code"; fail=$((fail+1)); }

# Spaces are legal in tmux session names and must not word-split the sweep list.
SESSION2="agsup test 2"
tmux kill-session -t "$SESSION2" 2>/dev/null || true
tmux new-session -d -s "$SESSION2" -x 80 -y 24 -n win0 \
  'printf "Do you want to proceed?\n"; sleep 300'
sleep 1
rw=$(bash "$SWEEP" "$SESSION2"); rc=$?
[ "$rc" -eq 0 ] && pass=$((pass+1)) || { echo "FAIL: whitespace session exit $rc"; fail=$((fail+1)); }
check "whitespace session name"  '.sessions[0].session' "$SESSION2" "$rw"
check "whitespace session count" '.sessions | length' 1 "$rw"
check "whitespace session state" '.sessions[0].windows[0].state' waiting_permission "$rw"
tmux kill-session -t "$SESSION2" 2>/dev/null || true

tmux kill-session -t "$SESSION" 2>/dev/null || true
rm -rf "$AGENT_SUPERVISOR_STATE"
echo "sweep: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
