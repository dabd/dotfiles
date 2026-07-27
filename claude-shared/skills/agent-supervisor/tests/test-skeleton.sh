#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
SK=../skeleton.sh
pass=0; fail=0
expect() { # desc needle output
  if printf '%s\n' "$3" | grep -qF "$2"; then pass=$((pass+1));
  else echo "FAIL: $1 (missing: $2)"; fail=$((fail+1)); fi
}
absent() { # desc needle output
  if printf '%s\n' "$3" | grep -qF "$2"; then echo "FAIL: $1 (leaked: $2)"; fail=$((fail+1));
  else pass=$((pass+1)); fi
}

c=$(bash "$SK" fixtures/claude-transcript.jsonl)
expect "claude user line"      "USER: fix the flaky test" "$c"
expect "claude assistant line" "ASSISTANT: Found it" "$c"
expect "claude tool name"      "TOOL: Bash" "$c"
absent "claude tool output"    "HUGE TOOL OUTPUT" "$c"

# interleaved text/tool_use blocks in one turn keep their original order
order=$(printf '%s\n' "$c" \
  | grep -oE '(ASSISTANT: Interleave (one|two)|TOOL: (Read|Write))' | tr '\n' ',')
want="ASSISTANT: Interleave one,TOOL: Read,ASSISTANT: Interleave two,TOOL: Write,"
if [ "$order" = "$want" ]; then pass=$((pass+1));
else echo "FAIL: claude interleaved order (got: $order)"; fail=$((fail+1)); fi

x=$(bash "$SK" fixtures/codex-transcript.jsonl)
expect "codex user line"      "USER: bump the dependency" "$x"
expect "codex assistant line" "ASSISTANT: Dependency bumped" "$x"
expect "codex tool name"      "TOOL: shell" "$x"
expect "codex custom tool"    "TOOL: exec" "$x"
absent "codex tool output"     "HUGE EXEC OUTPUT" "$x"
absent "codex reasoning blob"  "OPAQUE REASONING BLOB" "$x"

# a transcript still being appended to ends in a partial JSON line
tmp="${TMPDIR:-/tmp}/skeleton-partial-$$"
mkdir -p "$tmp"
cat fixtures/claude-transcript.jsonl > "$tmp/partial.jsonl"
printf '{"type":"assis' >> "$tmp/partial.jsonl"
p=$(bash "$SK" "$tmp/partial.jsonl" 2>"$tmp/err"); pe=$?
expect "partial line narrative" "ASSISTANT: Found it" "$p"
[ "$pe" -eq 0 ] && pass=$((pass+1)) || { echo "FAIL: partial line exit ($pe)"; fail=$((fail+1)); }
[ ! -s "$tmp/err" ] && pass=$((pass+1)) || { echo "FAIL: partial line stderr not empty"; fail=$((fail+1)); }
rm -rf "$tmp"

bash "$SK" /nonexistent 2>/dev/null
[ $? -eq 2 ] && pass=$((pass+1)) || { echo "FAIL: missing-file exit"; fail=$((fail+1)); }

echo "skeleton: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
