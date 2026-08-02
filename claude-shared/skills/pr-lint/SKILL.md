---
name: pr-lint
description: Lint a pull request description against its diff - missing genre slots, silent riders in the code, and claims the diff does not support. Point it at a PR number/URL, or run bare on the working diff before publishing.
disable-model-invocation: true
---

# pr-lint

Answers one question: does the description tell the truth, the whole truth,
about this diff? It does not judge code quality; code review owns that lane.
This lint finds what is missing or inconsistent, which reviewers and linters
are structurally worst at seeing.

## Inputs

- `/pr-lint <number|url>`: fetch with `gh pr view` (description) and
  `gh pr diff` (code).
- `/pr-lint` with no argument: the working diff against the default-branch
  merge-base, plus the draft description under discussion (ask for it if none
  exists yet).
- Dial `--description-only`: run lane 1 only; no diff is read.

## Lane 1: slots (description alone)

Read `genre-slots.md` in this skill's directory. For each slot, mark it
present, absent, or not-applicable-with-reason. A slot is absent only when the
genre expects it for THIS change; a doc-only PR owes no rollback plan. When a
repo defines `.claude/pr-lint-slots.md`, read it after the bundled file: its
slots extend or override the defaults.

## Lane 2: diff sweep (code alone)

Sweep the hunks for description-worthy changes regardless of what the text
says: new or changed config keys and defaults, timeouts, retries, limits,
shared middleware or interceptors, public API surface, deleted or weakened
tests, dependency version changes, feature-flag reads, data-shape or wire
format changes, anything that moves metrics or logs.

## Lane 3: cross-check (description against diff)

- Diff to description: hunks no sentence accounts for. Name the rider.
- Description to diff: verify each strong claim ("X only", "no behavior
  change", "tests unchanged", "backwards compatible") against the hunks that
  could falsify it. Confirm or flag with the falsifying hunk.

## Evidence rule

No evidence, no finding. Lane 1 findings cite the slot name. Lane 2 and 3
findings cite a file and hunk. A hunch that cites nothing is not reported.

## Output

A findings table, one row per finding:

| finding | lane | class | evidence | proposed sentence |

`class` is the omission class when one fits: buried-bad-news (consequence the
reader needs and would not welcome), bedrock (context obvious to the author,
missing for the next reader), optionality (commitment avoided). The proposed
sentence is ready to paste, or a bracketed placeholder when only the author
knows the fact.

Null output is a pass, not a failure to dig: "description is complete and
consistent with the diff" ends the lint. Do not manufacture findings.

The user accepts or rejects each row. Repairs are folded into the draft and
then go through a conservative prose pass; this skill does not rewrite the
description itself.

## Anti-patterns

- Code review drift: commenting on implementation quality. Wrong lane.
- Style findings on the description prose. Wrong tool.
- Findings without a named slot or falsifying hunk.
- Padding: reporting present slots or confirmed claims as findings.
