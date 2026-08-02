---
name: blastradius
description: "Given a change (diff, PR, or described), enumerate what moves beyond the diff: callers, configs, metrics, dashboards, alerts, logs, wire formats, docs, downstream consumers. Every claimed edge is verified by search or labeled speculative."
disable-model-invocation: true
---

# Blast radius

A diff tells you what changed. It does not tell you what breaks. This skill
finds the second thing: the sites that depend on the changed names, values,
and formats but do not appear in the diff.

## Procedure

### 1. Read the change

Take the diff, the PR, or the described change and extract the *identifiers*
that cross a boundary:

- renamed or removed public symbols, constructor and method signatures
- config keys, environment variables, default values
- metric names, tag and dimension keys, log message shapes and fields
- wire and storage field names, enum values, serialized formats
- version numbers, published artifact coordinates
- behavior removed from a hot path: a deleted middleware, guard, or
  recording site has no name in the additions, and its absence is often the
  largest radius item (counts drop, semantics shift)

Write that list down before searching. Everything downstream keys off it.
Also write down the changed-file set: exclude those files from every search
below, or the diff pollutes its own radius (worse when the checkout already
contains the change).

### 2. Search per category

Read `categories.md` in this skill directory. Work the categories in order.
For each one, run its search commands against the identifier list. A category
you searched and found nothing in is a result: record it as clear.

### 3. Resolve through the repo map, if present

If the target repo has `.claude/blastradius-map.md`, read it **after**
`categories.md`, and re-resolve each category through it. The map says where
dashboards, monitors, consumers, and runbooks actually live for that repo. It
turns generic categories into concrete paths, and it usually upgrades rows
from speculative to verified. Absent map: proceed on the generic categories
and say so.

### 4. Emit the table

| Affected thing | Category | Evidence | Verified? | Action owner |

- **Affected thing**: the specific site, not the area. A path, a symbol, a
  dashboard name, a consuming repo.
- **Category**: from `categories.md`.
- **Evidence**: `file:line`, a grep hit, a commit SHA, or the search that
  found it. For speculative rows, the reason you suspect it.
- **Verified?**: `verified` or `speculative`.
- **Action owner**: who or what absorbs the follow-up. Inside the repo:
  this PR, a follow-up change, oncall. Across a boundary, name the target
  artifact, not a role: the dashboard, the runbook step, the consuming
  repo. "External infra owner" is honest and useless; "the release
  checklist's monitoring step" is actionable.

Sort verified rows first. Below the table, list the categories that came back
clear, so the reader can tell "searched, nothing" from "never looked".
Categories overlap (a metric whose meaning shifts is also an operational
expectation): emit each finding once, under the category whose evidence
found it.

## Rules

- Speculation is allowed and expected. Discovery is the point, and a
  speculative row that turns out wrong costs less than a missed consumer. Mark
  it `speculative` and say why you suspect it.
- Every `verified` row cites a concrete artifact: a `file:line`, a grep hit, a
  commit. No citation means the row is speculative. There is no third state.
- `verified` covers the CONSEQUENCE, not just the artifact. Finding the site
  proves it exists; the row's claim is what happens to it. Before marking
  verified, check the three ways an existing site fails to matter:
  - reachability: is the site actually on the path the change affects, or
    wired into a branch the affected traffic never takes?
  - liveness: does anything reference it? A zero-reference site has no blast
    radius; report it as dead code, not impact.
  - co-variance, for cardinality and rebaseline claims: two keys carrying
    the same value multiply nothing, and removing one moves no numbers.
  A row whose artifact is verified but whose consequence is not stays
  speculative, with the missing check named.
- Null output is a valid result. A genuinely self-contained change gets an
  empty table plus the list of categories searched.
- Search before you assert. If a search is impossible here (no access to the
  consuming repo, no infra checkout), say that in the evidence column and mark
  the row speculative.

## Anti-patterns

- Listing files from the diff as blast radius. The diff is the input; the
  radius is what the diff does not contain.
- Marking a row `verified` on reasoning alone. Reasoning produces speculative
  rows.
- Enumerating every theoretical consumer without searching for any of them. A
  long unsearched list reads as thorough and is worth nothing.
- Reporting a category as clear when you never ran a search for it.
