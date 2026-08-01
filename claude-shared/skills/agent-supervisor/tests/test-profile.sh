#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
SWEEP=../sweep.sh
pass=0; fail=0

check() { # label expected cmd...
  local label=$1 expected=$2; shift 2
  got=$("$@")
  if [ "$got" = "$expected" ]; then pass=$((pass+1));
  else echo "FAIL: $label expected '$expected' got '$got'"; fail=$((fail+1)); fi
}

# Dir-to-name mapping is the hermetic half of profile detection. The ps-based
# tree walk is not unit-testable: macOS procargs visibility varies by spawner
# (env of freshly spawned test children is hidden, env of real tmux agents is
# readable), so the walk is verified against live panes, not fixtures.
check "personal dir"  personal        bash "$SWEEP" --profile-from-dir "$HOME/.codex-personal" .codex
check "stock dir"     default         bash "$SWEEP" --profile-from-dir "$HOME/.codex" .codex
check "suffixed dir"  kimi            bash "$SWEEP" --profile-from-dir "$HOME/.claude-kimi" .claude
check "foreign dir"   .claude-personal bash "$SWEEP" --profile-from-dir "$HOME/.claude-personal" .codex

# Kind gating: non-agent kinds never report a profile, and an empty pane pid
# must fall through to "" rather than erroring under set -u.
check "shell kind"    "" bash "$SWEEP" --detect-profile 1 shell
check "other kind"    "" bash "$SWEEP" --detect-profile 1 other
check "empty pid"     "" bash "$SWEEP" --detect-profile "" codex

echo "profile: $pass passed, $fail failed"
exit "$((fail > 0))"
