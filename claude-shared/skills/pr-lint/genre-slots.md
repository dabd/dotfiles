# PR description genre slots

What a complete PR description says, one slot per line. Lane 1 of pr-lint
marks each slot present, absent, or not-applicable-with-reason for the change
at hand. A repo can extend or override these in `.claude/pr-lint-slots.md`.

- **motivation**: why this change, and why now. A ticket link alone passes
  only if the ticket states the problem.
- **change list**: what changed, at the level a reviewer navigates by.
- **scope boundary**: what deliberately did not change, when a reader would
  plausibly assume otherwise.
- **verification**: how THIS change was tested, as deployed. Evidence carried
  over from a larger reviewed tree does not cover a part that ships alone.
- **risk**: what breaks if this is wrong, and the first symptom.
- **rollback**: the revert story, and any asymmetry (revert reintroduces a
  cost, forces a second migration, loses data).
- **observability impact**: metrics, logs, traces, dashboards, or alerts that
  move; whether monitors fire at deploy; who must rebaseline.
- **sequencing**: ordering constraints with other PRs, deploys, flags, or
  migrations; what must stay off or false until when.
- **migration and config**: new or changed keys, defaults, flags; what
  operators must do, before or after.
- **compatibility**: wire, storage, and API compatibility for mixed-version
  windows during rollout.
