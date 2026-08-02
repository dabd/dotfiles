---
name: premortem
description: "Before shipping a change, design, or rollout: write the incident review from six months in the future, as if it already failed. Mechanism-complete failure narratives with the cheapest pre-ship check for each."
disable-model-invocation: true
---

# Premortem

"What are the risks?" produces hedged, unranked, unactionable answers. "It is
six months later, this shipped, and it failed - write the incident review"
produces concrete ones. The failure is stipulated, so the only remaining
question is *how*, and the answer has to be a mechanism. That is prospective
hindsight, and the whole skill is holding yourself to the second framing.

## Procedure

### 1. Read the change for mechanism, not for area

Read the diff or design. Write down the parts that can carry a failure: the
inputs it accepts, the state it holds, the order it assumes, the config keys
that steer it, the calls it makes, the behavior it removes. A narrative can
only ride something on this list.

Activation scope: if the change enables, schedules, or unblocks an existing
code path - a migration that turns on workflows, a flag that routes traffic
to dormant code - that path is in scope even though it is not in the diff.
The worst fallout of an activation change usually lives in what it switched
on, not in what it edited.

### 2. Stipulate the failure and write the incident review

For each candidate, put yourself six months out. The page fired, the review
is being written, and your job is to explain what happened. Then write it
down with exactly these five fields:

- **Trigger**: the input, state, or event that starts it. A specific one: a
  request shape, a deploy ordering, a key that goes hot. Not "high load".
- **Propagation**: the path through *named* code or config. File, symbol, or
  config key at each hop. This field is what separates a narrative from a
  worry.
- **Why monitoring missed it**: name the existing monitor, log line, alert,
  or dashboard that should have caught it, and say why it does not. If the
  answer is "nothing covers this path", that is the finding - but then also
  name the dashboard or alert family that *would* own it, so the field
  still discriminates when you cannot see the monitoring config.
- **First misleading symptom**: what oncall sees first, and what they
  reasonably misdiagnose it as. The gap between the symptom and the cause is
  the incident's real cost.
- **Cheapest pre-ship check**: one test, query, grep, or config assertion
  that would rule this narrative out before merge. Cheapest, not most
  thorough.

### 3. Rank and cut

Emit 2 to 4 narratives ordered by plausibility. Rank by argument, not by
number: say what makes the top one more likely than the next. Cut anything
whose propagation field you could not fill with real names - and record the
cuts in one line each ("considered and cut: X, because Y"). The cut list is
how the reader tells ranked judgment from a fixed quota.

## Rules

- **Evidence rule**: every narrative names the code path or config it rides.
  A narrative that cannot cite a file, symbol, or key is not a narrative, it
  is a mood. Delete it.
- **Null output is a valid result.** A genuinely boring change gets "no
  mechanism-complete failure narrative found", plus a list of what you
  examined and why each part cannot carry a failure. A docs change, a comment
  fix, a version bump with no behavior attached: these should usually come
  back null. Producing four narratives for one of them is worse than
  producing none.
- Stay inside what the change touches. A pre-existing problem the diff
  neither creates nor worsens belongs in a review comment, not here.
- If a field is genuinely unknown (no access to the monitoring config, say),
  write that in the field. An admitted gap is information; an invented
  monitor name is not.

## Anti-patterns

- **FUD lists**: "this could cause data loss", "there may be a race". Risks
  without mechanisms. Every item needs a path.
- **Probability theater**: invented percentages, "70% likely". You have no
  basis for the number and it launders a guess as a measurement. Rank by
  argument instead.
- **"A bug happens somewhere"**: a narrative whose trigger is "the new code
  is wrong" predicts nothing and rules nothing out.
- **Padding to four.** The count is a ceiling, not a quota. One solid
  narrative beats four where three are filler.
- Restating the diff as risk. That the change touches the retry path is not
  a narrative; how a specific retry storms is.
