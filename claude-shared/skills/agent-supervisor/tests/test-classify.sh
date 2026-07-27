#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
SWEEP=../sweep.sh
pass=0; fail=0

check() { # fixture kind expected
  got=$(bash "$SWEEP" --classify "fixtures/$1" "$2")
  if [ "$got" = "$3" ]; then pass=$((pass+1));
  else echo "FAIL: $1/$2 expected $3 got $got"; fail=$((fail+1)); fi
}

check_kind() { # fixture pane_current_command expected
  got=$(bash "$SWEEP" --detect-kind "fixtures/$1" "$2")
  if [ "$got" = "$3" ]; then pass=$((pass+1));
  else echo "FAIL: detect-kind $1/$2 expected $3 got $got"; fail=$((fail+1)); fi
}

check claude-permission.txt claude waiting_permission
check claude-working.txt    claude working
check claude-idle.txt       claude idle
check codex-approval.txt    codex  waiting_permission
check codex-working.txt     codex  working
check shell-prompt.txt      shell  exited
check garbage.txt           claude unknown

# Real (sanitized) idle chrome from live panes: flat prompt caret, context
# meter, mode line. No box drawing, so the boxed-prompt patterns miss these.
check claude-idle-real.txt  claude idle
check codex-idle-real.txt   codex  idle

# pane_current_command is unreliable: Claude Code reports its version string,
# Codex CLI reports node. Content decides; the command name is the fallback.
check_kind claude-idle-real.txt 2.1.220 claude
check_kind codex-idle-real.txt  node    codex
check_kind shell-prompt.txt     zsh     shell

# An unreadable pane file must classify as unknown, silently, exit 0.
check_unreadable() {
  errf=$(mktemp "${TMPDIR:-/tmp}/agent-supervisor-test.XXXXXX")
  got=$(bash "$SWEEP" --classify /nonexistent/path claude 2>"$errf")
  rc=$?
  err=$(cat "$errf"); rm -f "$errf"
  if [ "$got" = unknown ] && [ "$rc" -eq 0 ] && [ -z "$err" ]; then pass=$((pass+1));
  else echo "FAIL: unreadable expected unknown/rc0/no-stderr got '$got'/rc$rc/stderr '$err'"; fail=$((fail+1)); fi
}

# Sourcing must not exit the caller, even under set -euo pipefail.
check_sourceable() {
  got=$(bash -c "set -euo pipefail; . '$SWEEP'; classify_pane fixtures/claude-idle.txt claude; echo sourced-ok")
  if [ "$got" = "idle
sourced-ok" ]; then pass=$((pass+1));
  else echo "FAIL: sourcing expected 'idle/sourced-ok' got '$got'"; fail=$((fail+1)); fi
}

check_unreadable
check_sourceable

echo "classify: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
