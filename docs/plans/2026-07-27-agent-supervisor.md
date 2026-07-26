# agent-supervisor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Dispatch implementation subagents on Opus 5 (`model: "opus"`); the orchestrating session reviews each task against the spec before moving on.

**Goal:** Build the agent-supervisor skill: a read-only tmux fleet status board (sweep mode) and since-yesterday brief (brief mode) per `docs/specs/2026-07-27-agent-supervisor-design.md`.

**Architecture:** Deterministic bash scripts (`sweep.sh`, `skeleton.sh`) do the mechanical work: pane capture, diff, classification, transcript skeleton extraction. A `SKILL.md` instructs the supervising Claude session how to run them, judge the output, loop, and assemble briefs. Shipped from `claude-shared/skills/agent-supervisor/` in this repo, symlinked into both Claude profiles.

**Tech Stack:** bash (macOS `/bin/bash` 3.2 compatible: no `declare -A`, no `mapfile`), `tmux`, `jq`. No other dependencies.

## Global Constraints

- Repo is public-bound: no employer names, ticket prefixes, or machine-specific paths in any committed file. No em dashes or smart quotes in committed prose; use commas, colons, or ` - `.
- Read-only with respect to other sessions: no `tmux send-keys` anywhere in this feature.
- State dir: `~/.local/state/agent-supervisor/<session>/`, overridable via `AGENT_SUPERVISOR_STATE` env var (tests rely on the override).
- Skill source lives at `claude-shared/skills/agent-supervisor/`.
- Commit style: conventional prefix (`feat:`, `test:`, `docs:`, `chore:`), no emojis, no Co-Authored-By trailers.
- Test fixtures are hand-written mimics of agent UIs, never captures of real work sessions.

---

## File Structure

| File | Responsibility |
|---|---|
| `claude-shared/skills/agent-supervisor/sweep.sh` | Pane capture, snapshot diff, classification, compact JSON report |
| `claude-shared/skills/agent-supervisor/skeleton.sh` | Transcript skeleton extraction (Claude and Codex JSONL) |
| `claude-shared/skills/agent-supervisor/SKILL.md` | Skill instructions: sweep loop, brief procedure, limits |
| `claude-shared/skills/agent-supervisor/tests/run.sh` | Runs all test scripts, exits nonzero on any failure |
| `claude-shared/skills/agent-supervisor/tests/test-classify.sh` | Unit tests for classification against fixture pane texts |
| `claude-shared/skills/agent-supervisor/tests/test-sweep.sh` | Integration test against a scratch tmux session |
| `claude-shared/skills/agent-supervisor/tests/test-skeleton.sh` | Skeleton extraction tests against fixture transcripts |
| `claude-shared/skills/agent-supervisor/tests/fixtures/` | Hand-written pane texts and JSONL transcripts |
| `home.nix` | One new `home.file` line wiring `.claude-personal/skills` |

---

### Task 1: Classification core in sweep.sh

**Files:**
- Create: `claude-shared/skills/agent-supervisor/sweep.sh`
- Create: `claude-shared/skills/agent-supervisor/tests/run.sh`
- Create: `claude-shared/skills/agent-supervisor/tests/test-classify.sh`
- Create: `claude-shared/skills/agent-supervisor/tests/fixtures/` (six pane fixtures, below)

**Interfaces:**
- Produces: `sweep.sh --classify <file> <agent-kind>` prints exactly one of `waiting_permission|working|idle|exited|unknown` and exits 0. `<agent-kind>` is one of `claude|codex|shell|other`. Task 2 calls the internal function `classify_pane <file> <kind>` in the same file. Task 2 also relies on `sweep.sh` sourcing cleanly with `set -euo pipefail`.

- [ ] **Step 1: Write the failing tests**

Create `tests/run.sh`:

```bash
#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"
fail=0
for t in test-*.sh; do
  echo "== $t"
  bash "$t" || fail=1
done
exit $fail
```

Create `tests/test-classify.sh`:

```bash
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
```

Create the fixtures (hand-written UI mimics):

`fixtures/claude-permission.txt`:
```
  Bash(rm -rf build/)

  Do you want to proceed?
  ❯ 1. Yes
    2. Yes, and don't ask again for rm commands
    3. No, and tell Claude what to do differently
```

`fixtures/claude-working.txt`:
```
✳ Baking noodles... (esc to interrupt · 42s · 12.1k tokens)
```

`fixtures/claude-idle.txt`:
```
╭──────────────────────────────────────────────╮
│ >                                            │
╰──────────────────────────────────────────────╯
  ? for shortcuts
```

`fixtures/codex-approval.txt`:
```
  codex wants to run: git push origin main

  Allow command?
  ▌ Yes  ▌ No
```

`fixtures/codex-working.txt`:
```
▌ Working  (Esc to interrupt)
```

`fixtures/shell-prompt.txt`:
```
~/projects/thing on main
❯
```

`fixtures/garbage.txt`:
```
lorem ipsum dolor sit amet
no recognizable agent chrome here
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash claude-shared/skills/agent-supervisor/tests/run.sh`
Expected: FAIL (sweep.sh does not exist yet).

- [ ] **Step 3: Implement sweep.sh with the classifier**

```bash
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash claude-shared/skills/agent-supervisor/tests/run.sh`
Expected: `classify: 7 passed, 0 failed`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add claude-shared/skills/agent-supervisor
git commit -m "feat: agent-supervisor pane classifier with fixture tests"
```

---

### Task 2: Sweep loop, snapshot diff, JSON report

**Files:**
- Modify: `claude-shared/skills/agent-supervisor/sweep.sh` (replace the trailing not-implemented stub)
- Create: `claude-shared/skills/agent-supervisor/tests/test-sweep.sh`

**Interfaces:**
- Consumes: `classify_pane`, `kind_from_command` from Task 1.
- Produces: `sweep.sh [session ...]` (no args: all tmux sessions) prints one JSON object to stdout:

```json
{
  "generated_at": "2026-07-27T09:00:00Z",
  "sessions": [
    {
      "session": "name",
      "windows": [
        {
          "index": 3,
          "name": "window name",
          "agent": "claude",
          "state": "working",
          "changed": true,
          "unchanged_sweeps": 0,
          "possibly_stuck": false,
          "tail": ["last lines..."]
        }
      ]
    }
  ]
}
```

`tail` is present only when `changed` is true, or `state` is `waiting_permission`, `exited`, or `unknown`, or `possibly_stuck` is true; otherwise it is `[]`. Exit 2 with a message on stderr if tmux is not running or a named session does not exist. SKILL.md (Task 4) documents this contract verbatim.

- [ ] **Step 1: Write the failing integration test**

Create `tests/test-sweep.sh`:

```bash
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
sleep 1

r1=$(bash "$SWEEP" "$SESSION")
check "win0 working"       '.sessions[0].windows[0].state' working "$r1"
check "win1 permission"    '.sessions[0].windows[1].state' waiting_permission "$r1"
check "first sweep changed" '.sessions[0].windows[0].changed' true "$r1"
check "working has no tail after..." '.sessions[0].windows[0].tail | length > 0' true "$r1"
check "session name"       '.sessions[0].session' "$SESSION" "$r1"

r2=$(bash "$SWEEP" "$SESSION")
check "second sweep unchanged" '.sessions[0].windows[0].changed' false "$r2"
check "unchanged counter"      '.sessions[0].windows[0].unchanged_sweeps' 1 "$r2"
check "quiet unchanged working tail" '.sessions[0].windows[0].tail | length' 0 "$r2"

r3=$(bash "$SWEEP" "$SESSION"); r4=$(bash "$SWEEP" "$SESSION")
check "stuck after 3 unchanged" '.sessions[0].windows[0].possibly_stuck' true "$r4"

bash "$SWEEP" no-such-session >/dev/null 2>&1
[ $? -eq 2 ] && pass=$((pass+1)) || { echo "FAIL: bad session exit code"; fail=$((fail+1)); }

tmux kill-session -t "$SESSION" 2>/dev/null || true
rm -rf "$AGENT_SUPERVISOR_STATE"
echo "sweep: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

Note: on the first sweep every window is `changed: true` (spec: state dir absent means first run, everything reports changed once). `possibly_stuck` requires `state == working` and `unchanged_sweeps >= 3`. The test panes run under `sh`, so `kind_from_command` yields `shell` or `other`; the integration test asserts plumbing (states via text patterns, diff, counters, JSON shape), while kind-specific behavior is covered by Task 1 unit tests.

- [ ] **Step 2: Run test to verify it fails**

Run: `bash claude-shared/skills/agent-supervisor/tests/run.sh`
Expected: test-classify passes; test-sweep FAILs with "sweep mode not implemented yet".

- [ ] **Step 3: Implement the sweep loop**

Replace the stub at the end of `sweep.sh` (keep the `--classify` branch) with:

```bash
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
      tail_json=$(grep -v '^[[:space:]]*$' "$snap" | tail -"$REPORT_TAIL" | jq -R . | jq -s .)
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash claude-shared/skills/agent-supervisor/tests/run.sh`
Expected: both scripts pass, exit 0. If a tmux-timing assertion flakes, add `sleep 1` after window creation, not longer captures.

- [ ] **Step 5: Manual acceptance against a real session**

Run `bash claude-shared/skills/agent-supervisor/sweep.sh <your-work-session> | jq .` in a terminal with live agent windows. Confirm states look sane; where a live Claude/Codex pane classifies as `unknown`, adjust the patterns in `classify_pane` and add a sanitized fixture reproducing the miss (never commit real pane content). This tuning loop is expected maintenance per the spec.

- [ ] **Step 6: Commit**

```bash
git add claude-shared/skills/agent-supervisor
git commit -m "feat: agent-supervisor sweep loop with snapshot diff and JSON report"
```

---

### Task 3: Transcript skeleton extraction

**Files:**
- Create: `claude-shared/skills/agent-supervisor/skeleton.sh`
- Create: `claude-shared/skills/agent-supervisor/tests/test-skeleton.sh`
- Create: `tests/fixtures/claude-transcript.jsonl`, `tests/fixtures/codex-transcript.jsonl`

**Interfaces:**
- Produces: `skeleton.sh <transcript.jsonl>` prints one line per event to stdout:
  - `[<iso-ts>] USER: <text, truncated to 500 chars>`
  - `[<iso-ts>] ASSISTANT: <text, truncated to 500 chars>`
  - `[<iso-ts>] TOOL: <tool name>`

  Tool outputs and file contents never appear. Format auto-detected: Claude lines have top-level `.type == "user"|"assistant"` with `.message`; Codex lines have `.payload`. Exit 2 on unreadable file. SKILL.md (Task 4) tells brief-mode subagents to read transcripts only through this script.

- [ ] **Step 1: Write the failing test and fixtures**

`tests/fixtures/claude-transcript.jsonl` (hand-written, sanitized):

```json
{"type":"last-prompt","sessionId":"x"}
{"type":"user","timestamp":"2026-07-27T08:00:00.000Z","message":{"role":"user","content":"fix the flaky test in widget-service"}}
{"type":"assistant","timestamp":"2026-07-27T08:00:05.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Looking at the test now."},{"type":"tool_use","name":"Bash","input":{"command":"grep -r flaky ."}}]}}
{"type":"user","timestamp":"2026-07-27T08:00:06.000Z","message":{"role":"user","content":[{"type":"tool_result","content":"HUGE TOOL OUTPUT THAT MUST NOT APPEAR"}]}}
{"type":"assistant","timestamp":"2026-07-27T08:00:10.000Z","message":{"role":"assistant","content":[{"type":"text","text":"Found it: the test races on a shared temp dir. Fixing."}]}}
```

`tests/fixtures/codex-transcript.jsonl`:

```json
{"timestamp":"2026-07-27T08:00:00.000Z","type":"session_meta","payload":{"id":"x","cwd":"/tmp/proj"}}
{"timestamp":"2026-07-27T08:01:00.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"bump the dependency"}]}}
{"timestamp":"2026-07-27T08:01:30.000Z","type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{\"command\":[\"npm\",\"install\"]}"}}
{"timestamp":"2026-07-27T08:02:00.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Dependency bumped and lockfile updated."}]}}
```

`tests/test-skeleton.sh`:

```bash
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

x=$(bash "$SK" fixtures/codex-transcript.jsonl)
expect "codex user line"      "USER: bump the dependency" "$x"
expect "codex assistant line" "ASSISTANT: Dependency bumped" "$x"
expect "codex tool name"      "TOOL: shell" "$x"

bash "$SK" /nonexistent 2>/dev/null
[ $? -eq 2 ] && pass=$((pass+1)) || { echo "FAIL: missing-file exit"; fail=$((fail+1)); }

echo "skeleton: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash claude-shared/skills/agent-supervisor/tests/run.sh`
Expected: test-skeleton FAILs (skeleton.sh missing); the other two suites still pass.

- [ ] **Step 3: Implement skeleton.sh**

```bash
#!/usr/bin/env bash
# agent-supervisor skeleton: narrative-only view of an agent transcript.
# Emits USER/ASSISTANT text and TOOL names; never tool outputs or file bodies.
set -euo pipefail

f="${1:-}"
[ -r "$f" ] || { echo "cannot read transcript: $f" >&2; exit 2; }

if head -20 "$f" | jq -e 'select(.payload != null)' >/dev/null 2>&1; then
  # Codex rollout format
  jq -r '
    select(.type == "response_item") | .timestamp as $ts | .payload
    | if .type == "message" and .role == "user" then
        "[\($ts)] USER: \([.content[]? | .text // empty] | join(" ") | .[0:500])"
      elif .type == "message" and .role == "assistant" then
        "[\($ts)] ASSISTANT: \([.content[]? | .text // empty] | join(" ") | .[0:500])"
      elif .type == "function_call" then
        "[\($ts)] TOOL: \(.name)"
      else empty end
    | select(test(": $") | not)
  ' "$f"
else
  # Claude Code format
  jq -r '
    select(.type == "user" or .type == "assistant") | .timestamp as $ts
    | if .type == "user" then
        (.message.content
         | if type == "string" then .
           else ([.[]? | select(.type == "text") | .text] | join(" ")) end
         | select(length > 0)
         | "[\($ts)] USER: \(.[0:500])")
      else
        ((.message.content[]? | select(.type == "text")
          | "[\($ts)] ASSISTANT: \(.text[0:500])"),
         (.message.content[]? | select(.type == "tool_use")
          | "[\($ts)] TOOL: \(.name)"))
      end
  ' "$f"
fi
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash claude-shared/skills/agent-supervisor/tests/run.sh`
Expected: all three suites pass, exit 0.

- [ ] **Step 5: Manual acceptance on a real transcript**

Run `bash skeleton.sh` on the newest file under `~/.claude/projects/*/` and under `~/.codex/sessions/*/*/*/`. Confirm output is narrative-only and a few hundred lines at most. If the live Codex payload shape differs from the fixture, fix the jq filter and update the fixture to match the real shape (sanitized).

- [ ] **Step 6: Commit**

```bash
git add claude-shared/skills/agent-supervisor
git commit -m "feat: agent-supervisor transcript skeleton extraction"
```

---

### Task 4: SKILL.md

**Files:**
- Create: `claude-shared/skills/agent-supervisor/SKILL.md`

**Interfaces:**
- Consumes: `sweep.sh` CLI contract (Task 2), `skeleton.sh` CLI contract (Task 3).
- Produces: the skill a supervising session invokes as `/agent-supervisor` (sweep) or `/agent-supervisor brief`.

- [ ] **Step 1: Write SKILL.md**

Frontmatter:

```yaml
---
name: agent-supervisor
description: Use when supervising multiple coding-agent tmux sessions - sweep window states into a delta status report on a self-scheduled loop, or build a morning brief and standup draft from session transcripts and git history ("what's stuck?", "status of my sessions", "morning brief", "standup draft").
---
```

Body must contain these sections, written as instructions to the supervising session (concise, imperative; scripts referenced relative to the skill dir):

1. **Scope and safety.** Read-only: never `send-keys`, never dispatch work. Both scripts live in this skill's directory; state lives in `~/.local/state/agent-supervisor/`.
2. **Sweep mode (default).** Run `sweep.sh [session ...]` (no args: all sessions). Report deltas only: what finished, what newly waits on the user, what is `waiting_permission`, `possibly_stuck`, `exited`, or `unknown`. One line per notable window; say nothing about unchanged `working`/`idle` windows; if nothing is notable, say so in one line. For `unknown`, show the tail instead of guessing. Then self-schedule the next sweep in 15-20 minutes and keep looping until the user says stop.
3. **Ad-hoc questions.** Between sweeps, re-run `sweep.sh` for current state. For depth on one window ("what happened with X"), find that window's transcript (procedure in section 5), run `skeleton.sh` on it, and if the skeleton is insufficient, spawn one subagent to read the relevant span of the raw transcript, tool outputs included. This raw-transcript path is the only deep-dive path and runs on request only.
4. **Brief mode** (invoked with argument `brief`). Read `~/.local/state/agent-supervisor/last-brief` (epoch seconds; if absent, use 24h ago). Then:
   - Enumerate task windows: `tmux list-windows`/`list-panes -F '#{pane_current_path}'` for each session; window names are task labels, pane paths locate the repos.
   - Locate transcripts modified since the timestamp: Claude under `~/.claude/projects/*/` and `~/.claude-personal/projects/*/` (`find -newer`-style mtime filter; match project slug to pane path); Codex under `~/.codex/sessions/` and `~/.codex-personal/sessions/` (match `session_meta.cwd` to pane path).
   - Fan out one subagent per task window, briefed with: the window name, the `skeleton.sh` output for its transcripts, and `git log --since=<timestamp> --oneline` for its repo. Each answers exactly three questions: what was attempted, what completed, what is blocked and why. Cross-check "completed" against git; report "claims done, nothing committed" when they disagree. No correctness judgment, no code review.
   - Gather `gh` PR activity across the repos found in pane paths (`gh pr list --author @me` state filters, since the timestamp).
   - If window names contain ticket keys (regex `[A-Z]+-[0-9]+`) and a ticket CLI is available on PATH, pull current ticket status; skip silently if not.
   - Merge into two outputs: a **morning brief** (per task: where it left off, what needs a decision, ordered by urgency) and a **standup draft** (yesterday/today/blockers). Route the standup draft through the prose skill. Both are drafts shown to the user; never post anything anywhere.
   - Write the new timestamp to `last-brief` only after delivering the brief.
5. **Finding a window's transcript** (shared by sections 3 and 4): take the window's `pane_current_path`; Claude project slug is the path with `/` replaced by `-` (prefix match under both profile dirs); for Codex, grep `session_meta` lines for a matching `cwd`. Prefer the most recently modified match.
6. **Limits.** The brief sees only agent and git activity: hand-done work, meetings, and chat context will not appear. It seeds the standup; the user writes the final version. Classification patterns drift with agent UI changes; `unknown` states are pattern-tuning signals, not errors.
7. **Errors.** Relay `sweep.sh` exit-2 messages verbatim and stop; no retries. Missing transcripts for a window: report "no agent history found" and fall back to git evidence.

Prose rules apply (repo is public: plain language, no em dashes, no work-specific names).

- [ ] **Step 2: Validate**

Run: `head -5 claude-shared/skills/agent-supervisor/SKILL.md` and confirm the frontmatter has exactly `name` and `description` keys and opens/closes with `---`. Grep the file for em dashes: `grep -n '-' claude-shared/skills/agent-supervisor/SKILL.md` must return nothing. Confirm every script invocation in the body matches the CLI contracts in Tasks 2 and 3.

- [ ] **Step 3: Commit**

```bash
git add claude-shared/skills/agent-supervisor/SKILL.md
git commit -m "feat: agent-supervisor skill instructions (sweep loop and brief mode)"
```

---

### Task 5: Wiring into both profiles

**Files:**
- Modify: `home.nix` (one line in the `home.file` block, after the `".claude-shared/prose-rules.md"` line)
- Modify: the private work-overlay repo's install script (local checkout; not part of this public repo)

**Interfaces:**
- Consumes: the completed skill directory from Tasks 1-4.
- Produces: `~/.claude-personal/skills/agent-supervisor/` and `~/.claude/skills/agent-supervisor/` both resolving to `~/dotfiles/claude-shared/skills/agent-supervisor/`.

- [ ] **Step 1: Add the personal-profile mapping**

In `home.nix`, add after the `".claude-shared/prose-rules.md"` line:

```nix
    ".claude-personal/skills".source = repoFile "claude-shared/skills";
```

Note: `~/.claude-personal/skills` must not already exist as a real directory; it is currently empty, so remove it first if home-manager reports a clobber conflict: `rmdir ~/.claude-personal/skills`.

- [ ] **Step 2: Switch and verify**

```bash
cd ~/dotfiles && home-manager switch --flake .#default --impure
readlink ~/.claude-personal/skills
ls ~/.claude-personal/skills/agent-supervisor/
```

Expected: symlink resolves into `~/dotfiles/claude-shared/skills`, listing shows `SKILL.md sweep.sh skeleton.sh tests`.

- [ ] **Step 3: Work-profile symlink**

Per the shared-agent-policy (overlay symlinks into this repo, never the reverse):

```bash
ln -sfn ~/dotfiles/claude-shared/skills/agent-supervisor ~/.claude/skills/agent-supervisor
readlink ~/.claude/skills/agent-supervisor
```

Then add the same `ln -sfn` line to the work-overlay repo's install script (the private repo checked out locally; follow its existing install-step pattern) and commit there with its conventions.

- [ ] **Step 4: End-to-end check**

Start a fresh `claude` session (work profile) and confirm `agent-supervisor` appears in the available-skills listing, then invoke `/agent-supervisor` against a live tmux session and confirm a delta report is produced.

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles
git add home.nix
git commit -m "feat: wire agent-supervisor skill into the personal claude profile"
```

---

## Verification (whole feature)

- `bash claude-shared/skills/agent-supervisor/tests/run.sh` exits 0.
- Manual: sweep against the real work session produces sane states; brief mode over a real day produces a usable morning brief and standup draft (spec: manual acceptance check).
- `grep -rn '-' claude-shared/skills/agent-supervisor/` returns nothing; no work-specific names anywhere in the skill directory.
