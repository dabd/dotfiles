#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
fail=0
for t in test-*.sh; do
  echo "== $t"
  bash "$t" || fail=1
done
exit $fail
