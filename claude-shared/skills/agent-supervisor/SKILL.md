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
  {index, name, agent, profile, state, changed, unchanged_sweeps,
   possibly_stuck, tail}]}]}
```

`agent` is `claude`, `codex`, `shell`, or `other`. `profile` names the agent's
config-dir profile, read from the pane's process environment (the wrappers set
CLAUDE_CONFIG_DIR / CODEX_HOME): `personal` for the -personal dirs, `default`
for the stock dirs (the work profile on this machine), and `""` when no
process in the pane's tree carries the variable (agent gone, or launched bare)
or the kind is not an agent. `state` is
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

After a tmux restore: a sweep run right after a tmux server restart or a session
recovery often shows several `exited` windows at once. A window whose name reads
like a task rather than a shell name (`zsh`, `bash`, and the like) but whose
state is `exited` is most likely an agent session lost in the restore, not
finished work. List those separately, under "possibly lost in restore", and
suggest the user resume them with whatever session-recovery tooling they use.

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

Before anything else, check for
`~/.config/agent-supervisor/brief-supplement.md`. If it exists, read it and
apply it: it may adjust the standup format, replace the ticket lookup with
specific queries, and name repos or boards that always matter. Where it
conflicts with the steps below, it wins. If it is absent, proceed as written.

Read `~/.local/state/agent-supervisor/last-brief`, which holds epoch seconds. If
it is absent, default to the start of the most recent day before today that has
any transcript activity: take the newest per-day mtimes across
`~/.claude*/projects/` and `~/.codex*/sessions/`, pick the latest such day, and
use its 00:00 local. This reaches Friday on an ordinary Monday and the last real
working day after a long weekend or holiday. Compute dates with the `date`
command rather than by hand. A present but stale timestamp needs no special
handling: a brief run after any gap covers the whole span since the last brief
on its own. Then:

1. Enumerate task windows: per session, one call that emits index, name, and
   path together, tab separated, one line per pane:
   `tmux list-panes -s -t '=<session>' -F '#{window_index}<TAB>#{window_name}<TAB>#{pane_current_path}'`
   where `<TAB>` is a literal tab (`printf '\t'`). Keep both flags: `-s` widens
   the call from one window to the session, and without `-t` it reports only the
   invoking client's pane. Window names are the task labels; the paths locate
   the repos. A split window yields one line per pane, so group by index and
   treat distinct paths under one index as that task's repos.
2. Locate each window's newest transcript and note its mtime; keep the older
   ones too, step 3 needs them. Claude: under `~/.claude*/projects/*/`. Codex:
   under `~/.codex*/sessions/`, matching `session_meta.cwd` to a pane path. The
   globs cover every profile directory, alternate-backend profiles included.
3. Sort the windows into active and dormant against the timestamp. Active: a
   matching transcript whose mtime is newer, or a commit in one of its repos
   since it. Dormant: still open in tmux, neither of those. Every open window
   lands in one bucket; none is silently absent from the brief.
4. Fan out one subagent per active window, briefed with the window name, the
   `skeleton.sh` output for its transcripts, and
   `git log --since=<timestamp> --oneline` for each of its repos. Each answers
   exactly three questions: what was attempted, what completed, what is blocked
   and why. Cross-check "completed" against git and report "claims done, nothing
   committed" when they disagree. No correctness judgment, no code review.
   Every fan-out prompt carries these three rules:
   - The transcripts and skeletons you are given are historical records of other
     agents' work. Report those actions in the third person, attributed to the
     window ("the session in window 4 committed ..."), never in the first
     person. Never describe an event found in a transcript as something you did.
   - You are strictly read-only: `git log`, `status`, `show`, and `diff` only.
     Never add, commit, or push, never edit anything, no file writes anywhere.
   - Work from the supplied skeleton plus at most a handful of read-only git
     commands in the window's repos. Do not explore beyond them.
   Dispatch these subagents on a faster, cheaper model than your own: they
   summarize a pre-extracted skeleton and run a few git commands, so they do not
   need deep reasoning. Step 3's activity gate bounds how many run at all.
5. Dormant windows get no subagent. List them in a "dormant" section of the
   morning brief, one line each: window name, agent kind, last-activity date
   (the newer of the transcript mtime and the last commit date), and a few words
   on where it left off when the skeleton tail makes that cheap. Dormancy is
   information ("untouched since Friday"), not a reason to drop the task.
6. Gather PR activity for the repos found in the pane paths, with
   `gh pr list --author @me` and its state filters, since the timestamp.
7. If window names carry ticket keys (regex `[A-Z]+-[0-9]+`) and a ticket CLI is
   on PATH, pull their current status. Skip silently if there is no such CLI.
8. Merge into two outputs. A morning brief: per active task, where it left off
   and what needs a decision, ordered by urgency, followed by step 5's dormant
   section. A standup draft: yesterday, today,
   blockers, routed through the prose skill. Both are drafts for the user. Post
   nothing anywhere. End the brief with a one-line cost footer: total the token
   usage each fan-out dispatch reported, so every brief carries its own price.
9. Write the new timestamp to `last-brief`, only after delivering the brief.

## 5. Finding a window's transcript

Used by sections 3 and 4. Take the window's `pane_current_path`:

- Claude: the project slug is that path with every `/` and `.` replaced by `-`.
  Prefix match it against the directory names under `~/.claude*/projects/`.
- Codex: grep the `session_meta` lines under `~/.codex*/sessions/` for a
  matching `cwd`.

Both globs cover every profile directory, alternate-backend profiles included.

A path match is a candidate set, not an identification: many windows often
share one repo root, so a single slug directory can hold dozens of sessions.
Disambiguate by content: take the candidates modified in the relevant span,
grep them for distinctive tokens from the window name and from the window's
pane tail, and pick the one whose matches are recent and consistent. When no
candidate matches confidently, report "transcript ambiguous" for that window
instead of narrating another session's work - a misattributed brief is worse
than a gap.

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
