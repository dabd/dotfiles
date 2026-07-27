---
name: agent-supervisor
description: Use when supervising multiple coding-agent tmux sessions - sweep window states into a delta status report on a self-scheduled loop, or build a morning brief and standup draft from session transcripts and git history ("what's stuck?", "status of my sessions", "morning brief", "standup draft").
---

# Agent supervisor

## 1. Scope and safety

You observe. You do not act on the fleet.

- Never run `tmux send-keys`, `respawn-pane`, `kill-window`, or anything else
  that writes to another session. Never answer an agent's permission prompt,
  never dispatch work into a window. Report what you see; the user drives.
- `sweep.sh` and `skeleton.sh` live in this skill's directory, next to this
  file. Invoke them with that directory prepended; below they are written bare.
- State lives under `~/.local/state/agent-supervisor/`: pane snapshots,
  unchanged-sweep counters, and the `last-brief` timestamp. A missing state dir
  is a first run, not an error: every window reports changed once, then deltas
  resume.

## 2. Sweep mode (default)

Run `sweep.sh [session ...]`. With no arguments it sweeps every tmux session.
It prints one JSON object:

```
{generated_at, sessions:[{session, windows:[
  {index, name, agent, state, changed, unchanged_sweeps, possibly_stuck,
   tail}]}]}
```

`agent` is `claude`, `codex`, `shell`, or `other`. `state` is
`waiting_permission`, `working`, `idle`, `exited`, or `unknown`.
`possibly_stuck` is true when a `working` pane produced no real output for 3 or
more consecutive sweeps. `tail` is populated only when the window changed, when
the state is `waiting_permission`, `exited`, or `unknown`, or when
`possibly_stuck` is true; otherwise it is `[]`.

Report deltas only, one line per notable window, naming session, index, name:

- finished: `working` last sweep, `idle` now.
- newly waiting on the user: `waiting_permission`, or newly `idle`. Say what it
  is asking for, from the tail.
- `possibly_stuck`: give the sweep count and the last thing it printed.
- `exited`: the pane's foreground process is a plain shell, so the agent is
  gone. That is inferred from the pane, not from an observed process exit, so
  say "pane is back to a shell", not "the process crashed".
- `unknown`: show the tail and stop there. Do not guess a state. The patterns
  live in `classify_pane` in `sweep.sh`, and an `unknown` on a live agent pane
  is a signal to tune them, not something to explain away.

Say nothing about unchanged `working` or `idle` windows. If nothing is notable,
say so in one line and no more. Then sweep again 15 to 20 minutes later, on a
timer the session already has (a recurring-prompt mechanism, or a backgrounded
sleep whose completion wakes you). Never block on a foreground sleep; it locks
the user out. Loop until the user says stop.

## 3. Ad-hoc questions between sweeps

For anything about current state ("what's stuck?", "is window 4 waiting?"),
re-run `sweep.sh`. Do not answer from the previous sweep; it is minutes stale.

For depth on one window ("what happened with X"), pane scrollback is too
shallow. Find that window's transcript by section 5, then run
`skeleton.sh <transcript.jsonl>`. It prints the narrative only, auto-detecting
Claude and Codex JSONL: each event begins a line, as `[<iso-ts>] USER: <text>`,
`[<iso-ts>] ASSISTANT: <text>`, or `[<iso-ts>] TOOL: <name>`, text truncated to
500 characters. Narrative text containing newlines continues across following
lines, so do not parse it as strictly one line per event. Tool outputs and file
contents never appear.

If the skeleton is not enough, spawn one subagent to read the relevant span of
the raw transcript, tool outputs included, and report a summary rather than the
content. This is the only deep-dive path, it is expensive, and it runs on
explicit request only.

## 4. Brief mode (argument `brief`)

Read `~/.local/state/agent-supervisor/last-brief`, which holds epoch seconds. If
it is absent, use 24 hours ago. Then:

1. Enumerate task windows: per session, one call that emits index, name, and
   path together, tab separated, one line per pane:
   `tmux list-panes -s -t '=<session>' -F '#{window_index}<TAB>#{window_name}<TAB>#{pane_current_path}'`
   where `<TAB>` is a literal tab (`printf '\t'`). Keep both flags: `-s` widens
   the call from one window to the session, and without `-t` it reports only the
   invoking client's pane. Window names are the task labels; the paths locate
   the repos. A split window yields one line per pane, so group by index and
   treat distinct paths under one index as that task's repos.
2. Locate transcripts modified since the timestamp. Claude: under
   `~/.claude/projects/*/` and `~/.claude-personal/projects/*/`, filtered on
   mtime. Codex: under `~/.codex/sessions/` and `~/.codex-personal/sessions/`,
   matching `session_meta.cwd` to a pane path.
3. Fan out one subagent per task window, briefed with the window name, the
   `skeleton.sh` output for its transcripts, and
   `git log --since=<timestamp> --oneline` for its repo. Each answers exactly
   three questions: what was attempted, what completed, what is blocked and why.
   Cross-check "completed" against git and report "claims done, nothing
   committed" when they disagree. No correctness judgment, no code review.
4. Gather PR activity for the repos found in the pane paths, with
   `gh pr list --author @me` and its state filters, since the timestamp.
5. If window names carry ticket keys (regex `[A-Z]+-[0-9]+`) and a ticket CLI is
   on PATH, pull their current status. Skip silently if there is no such CLI.
6. Merge into two outputs. A morning brief: per task, where it left off and what
   needs a decision, ordered by urgency. A standup draft: yesterday, today,
   blockers, routed through the prose skill. Both are drafts for the user. Post
   nothing anywhere.
7. Write the new timestamp to `last-brief`, only after delivering the brief.

## 5. Finding a window's transcript

Used by sections 3 and 4. Take the window's `pane_current_path`, then prefer the
most recently modified match from:

- Claude: the project slug is that path with every `/` replaced by `-`. Prefix
  match it against the directory names under `~/.claude/projects/` and
  `~/.claude-personal/projects/`.
- Codex: grep the `session_meta` lines under `~/.codex/sessions/` and
  `~/.codex-personal/sessions/` for a matching `cwd`.

## 6. Limits

- The brief sees agent transcripts and git activity only. Work done by hand,
  meetings, and chat context will not appear. It seeds the standup; the user
  writes the final version.
- Classification patterns drift as agent UIs change. `unknown` states are
  pattern-tuning signals, not errors.
- Change detection ignores known volatile output only, currently the
  esc-to-interrupt status line and its ticking timer. A pane running some other
  always-redrawing UI reports changed every sweep and will never look stuck.
- A tab character inside a tmux window name misparses the window listing. If a
  window's name or index looks wrong, check the name for a tab.

## 7. Errors

- `sweep.sh` exits 2 when tmux is not running or a named session does not
  exist. Relay its stderr message verbatim and stop. No retries.
- `skeleton.sh` exits 2 on an unreadable transcript. Relay and move on to the
  next window.
- No transcript found for a window: report "no agent history found" for that
  task and fall back to git evidence.
