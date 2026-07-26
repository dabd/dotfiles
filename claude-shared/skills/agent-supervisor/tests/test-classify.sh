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

check claude-permission.txt claude waiting_permission
check claude-working.txt    claude working
check claude-idle.txt       claude idle
check codex-approval.txt    codex  waiting_permission
check codex-working.txt     codex  working
check shell-prompt.txt      shell  exited
check garbage.txt           claude unknown

echo "classify: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
