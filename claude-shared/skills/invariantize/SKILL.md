---
name: invariantize
description: Extract the invariants a module or design depends on - what must stay true for it to keep working - each with where it is enforced today (or NOWHERE) and a proposed check as actual code or a command.
disable-model-invocation: true
---

# invariantize

Assumption archaeology pointed at code. A module works because certain things
stay true: an ordering is total, a byte sequence round-trips, a counter has one
writer. Some of those are pinned by a test or a type. Some are pinned by nothing
and hold only because nobody has poked them yet. This skill finds both and tells
them apart.

The NOWHERE rows are the deliverable. An invariant that everything relies on and
nothing enforces is the finding; a well-tested invariant is a footnote.

## Inputs

`/invariantize <path>`, `/invariantize <module or API name>`, or a pasted design.
Read the target first. Reading is not optional and not delegable to a summary.

## Procedure

1. Read the module for load-bearing assumptions, not for features. Ask of each
   function: what could a caller, a platform, or a future edit do that would
   make this silently wrong? Features answer "what does it do"; invariants
   answer "what would break it".
2. For each candidate, search for its enforcement before you write the row.
   Grep the test sources, the assertions, the types, the CI config. Record the
   searches you ran; you will cite them.
3. Emit one row per invariant, with exactly these fields:

   - **statement**: one sentence in "X stays true" form.
   - **kind**: one of ordering, encoding, numeric, clock, idempotency,
     single-writer, resource, protocol, platform, layering (implicit
     precedence, shadowing, module-boundary rules).
   - **enforced**: `file:line` of the test or assertion that pins it;
     `by-construction: file:line` when a private constructor or sealed
     hierarchy pins it structurally; `NOWHERE`; or `CONTRADICTED: file:line`
     when a comment or doc asserts the invariant and the code violates it -
     that row outranks everything else in the table.
   - **consequence**: what observably breaks if it stops holding. One sentence,
     concrete: wrong bytes, a hang, a lost write. Not "correctness suffers".
   - **check**: runnable content. A test skeleton, a property, a grep command,
     or an assertion. Actual text someone can paste, not a description of one.
     A one-liner goes in the row; anything longer goes in a code block below
     the table, keyed by row number.

4. Sort by severity: CONTRADICTED rows first, then NOWHERE, then enforced.

## Rules

- **Evidence rule.** Every enforcement claim cites `file:line`. Every NOWHERE
  claim names the searches that came back empty. "I did not find one" without
  the search is not a NOWHERE, it is a guess. Hoist the searches into one
  numbered list above the tables and cite them by number: the same search
  backs many rows, and repeating it per row buries the table.
- **Null output is allowed.** A thin module with two real invariants gets two
  rows. Padding a short table is the main way this skill fails.
- **Do not manufacture invariants for code you have not read.** If the module
  calls into something you did not open, say so and stop at the boundary.
- Line numbers drift. Cite the symbol name alongside the line so a stale
  number is still resolvable.

## Anti-patterns

- **Restating types as invariants.** "The list stays a list of strings" is
  pinned by the compiler. Skip it. A type-level pin only earns a row when the
  type is doing subtle work a refactor could quietly drop.
- **Documenting the obvious.** No rows for arithmetic, for "the parser parses",
  or for anything a reader would assume without being told.
- **Checks that cannot fail.** If the proposed check passes on any input, it is
  decoration. Ask: what edit would turn this check red? If nothing, cut it.
- **Paraphrasing existing test names as discoveries.** A test named
  `roundTripsUtf8` already states its invariant. Citing it as enforcement is
  correct; presenting it as an extraction is not. The value is in what the
  tests do not say.
- **Vague consequences.** "Undefined behavior" and "things get weird" are
  refusals to look. Trace one concrete failure.

## Output

A table sorted by severity (CONTRADICTED, NOWHERE, by-construction and
enforced), the numbered search list, and long checks in a code block keyed
by row. If a candidate turned out to be enforced by the compiler or by an
existing named test, drop it, and say in one line what you dropped and why -
the drop list is how the reader tells restraint from blindness.
