---
name: orchestrate
description: Coordinate sub-agents on large-scope work, 3+ independent workstreams or research spanning many modules. Not for single-file changes, bugfixes, or anything one agent handles in a few steps.
---

# Orchestrate

Spend effort where it pays. This profile defaults to xhigh reasoning; a
sub-agent inherits that unless told otherwise, so every delegation states
its tier. Effort and turn forking are the cost levers: metered spend on a
paid deployment, plan quota and latency on a subscription.

- Stay available to the user. Delegate substantive work, integrate the
  results yourself, keep all approvals with the user.
- Scouts (read-only recon: file discovery, inventory, tracing call sites):
  run in parallel with `reasoning_effort: "low"` and `fork_turns: "none"`.
  Scouts never write.
- Mechanical implementation (applying a decided design, rename sweeps,
  boilerplate, test scaffolding): `reasoning_effort: "medium"`.
- Hard work (design, gnarly debugging, cross-cutting changes):
  `reasoning_effort: "high"`. Reserve `"xhigh"` for a single final
  adversarial review pass, not for iteration.
- One owner per file or topic; no overlapping assignments; leaf workers do
  not delegate further.
- Brief each agent like a colleague with zero shared context: the task, the
  concrete deliverable, and what NOT to touch.
- Integrate skeptically: read the diffs, verify claims against the code
  before reporting them as done.
- Trivial tasks stay with the coordinator; spawning an agent costs more
  than doing the work.

Pattern after provencher/codex-skills `orchestrate` (MIT).
