# agent-supervisor: tmux fleet status board and daily brief

Date: 2026-07-27
Status: approved design, not yet implemented

## Problem

A working day runs many coding-agent sessions (Claude Code, Codex) in parallel,
one per tmux window, a dozen or more at a time. Two questions have no cheap
answer today:

1. Right now, which tasks are working, which are waiting on me, which are
   stuck or done?
2. Since yesterday, what happened across all of them, in a form that seeds a
   morning restart and a standup update?

Existing orchestration platforms (omnigent, cli-agent-orchestrator) run agents
inside their own harness. Nothing supervises an existing hand-built tmux
workflow, and adopting a platform would replace that workflow rather than
observe it. Full orchestration (dispatching new tasks) is explicitly out of
scope; those platforms cover it.

## Solution shape

A Claude Code skill plus a deterministic helper script, invoked from a plain
Claude session that acts as the supervisor. The skill is read-only with respect
to other sessions: it never sends keys, never dispatches work.

Two modes:

- **sweep**: what state is every window in right now, reported as deltas.
- **brief**: what happened since the last brief, reported as a morning brief
  and a standup draft.

## Components

### sweep.sh (deterministic layer)

A script shipped in the skill directory. Input: a tmux session name, default
all sessions. For each window it:

1. Captures the pane tail (`tmux capture-pane -p`, last ~200 lines).
2. Snapshots it under `~/.local/state/agent-supervisor/<session>/<window>` and
   diffs against the previous snapshot.
3. Classifies the pane with pattern checks, in order:
   - agent waiting on a permission or approval prompt
   - agent idle at its input prompt (turn finished)
   - bare shell prompt (agent exited)
   - output unchanged for N consecutive sweeps (possibly stuck)
   - otherwise: working
   - anything unrecognised: `unknown`, with the tail included so the model
     looks instead of guessing
4. Emits one compact JSON report: per window its name, agent kind
   (claude/codex/shell), state, changed flag, and tail lines only for windows
   that changed or need attention.

The script is the token control: an 18-window sweep costs the model a few
hundred lines, not 18 scrollbacks. It holds all the fragile pattern knowledge
in one testable place.

State dir: `~/.local/state/agent-supervisor/`. Holds pane snapshots, the
consecutive-unchanged counters, and the last-brief timestamp.

### SKILL.md (judgment layer)

The skill instructs the supervising session:

**Sweep mode** (default): run sweep.sh, then report a delta summary: what
finished, what is newly waiting on the user, what looks stuck, one line each.
Say nothing about unchanged working windows. Then self-schedule the next sweep
(15-20 minute wakeups) and loop until told to stop. Between sweeps the user
can ask ad-hoc questions ("what's stuck?", "summarize window 8"); answer by
re-running the script or, for depth, deep-diving that window's session
transcript with a subagent, since pane scrollback is too shallow for "what did
this task accomplish".

**Brief mode** (`brief` argument): build the since-yesterday picture from
durable sources, not panes:

- Transcripts: for each task window, locate Claude/Codex session logs touched
  since the last-brief timestamp; fan out one subagent per task to answer:
  what was attempted, what completed, what is blocked and why.
- Git: `git log --since` across the configured work tree, plus `gh` for PRs
  opened, merged, and reviewed. Ground truth for what shipped.
- Ticket system (optional): where window names contain ticket keys, pull
  current status via the locally configured ticket CLI if one exists.

Merge into two outputs: a morning brief (per task: where it left off, what
needs a decision first) and a standup draft in yesterday/today/blockers form.
The standup draft goes through the prose skill and is only ever a draft; the
supervisor posts nothing anywhere. Update the last-brief timestamp on
completion.

**Limits stated in the skill**: the brief only sees agent and git activity.
Hand-done work, meetings, and chat context will not appear. It seeds the
standup; the user writes the final version.

## Placement and wiring

Per the shared agent policy (README): shared, personal-safe policy lives in
this repo; the work overlay symlinks into it, never the reverse.

- Skill source: `claude-shared/skills/agent-supervisor/{SKILL.md,sweep.sh}`.
- Personal profile: `home.nix` maps `.claude-personal/skills` to it.
- Work profile: the overlay repo symlinks it into `~/.claude/skills/`
  alongside the managed skills there.

The repo is public-bound: the skill contains no employer-specific names,
paths, or ticket prefixes. Session names, work-tree roots, and the ticket CLI
are runtime input or machine-local config.

## Error handling

- tmux not running or session name wrong: script exits with a clear message;
  skill relays it, no retries.
- Unrecognised pane content: classified `unknown`, tail surfaced, never
  silently bucketed.
- Missing transcripts for a window (agent run outside the known log dirs):
  brief marks the task "no agent history found" and falls back to git
  evidence.
- State dir absent or corrupt: treat as first run; every window reports as
  changed once, then deltas resume.

## Testing

- sweep.sh: point it at a scratch tmux session with panes faked into each
  state (idle agent, permission prompt, dead shell, busy output) and assert
  the JSON. No agents needed.
- Classification patterns are the fragile part and will drift with Claude and
  Codex UI changes; the `unknown` state is the safety valve, and pattern fixes
  are the expected maintenance.
- Brief mode: run against a day of real sessions and check the draft against
  what actually happened; this stays a manual acceptance check.

## Out of scope (v1)

- Sending keys to other sessions (nudging).
- Dispatching new tasks, task queues, ticket intake.
- Any write to tickets, chat, or PRs.
