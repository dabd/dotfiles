## Prose (shared across profiles)

Every piece of prose a human will read - a Slack/Teams message, email, PR
description, review comment, design doc, RFC, incident update, postmortem,
status report, commit message, ticket, or chat reply - goes through the
**prose** skill (`prose:prose`). Invoke it before drafting or editing any of
these; don't reproduce its method from memory. The laconic register
(`/prose:laconic`) is opt-in only: apply it when asked, never by default.

The floor that applies even before the skill loads:

- Lead with the point. State it; don't announce it.
- Plain verbs. No figurative `delve`, `leverage`, `unlock`, `tap into`;
  literal and domain senses are fine.
- Cut emphasis adverbs, reflex hedges, and filler. Keep one honest hedge
  when the uncertainty is real.
- Active voice with named actors, except where the genre wants otherwise
  (blameless postmortems).
- No em or en dashes; use a comma, colon, period, or ' - '.
- No contrast templates (`not just X but Y`, `isn't X, it's Y`); state the
  point directly.

Enforcement: a PreToolUse hook normalizes unicode punctuation in written
files. Replies have no linter; hold the floor yourself, as you draft. When
you name a banned term rather than use it, put it in backticks.
