---
name: edgeledger
description: Enumerate the edge cases of a function, API, or format by structural family - each with expected behavior per the spec, where it is tested today (or NOWHERE), and a proposed test name.
disable-model-invocation: true
---

# edgeledger

Edge cases do not arrive one at a time. They arrive in families: the empty one,
the duplicate one, the one at the numeric boundary, the one the other platform
renders differently. Enumerating from memory finds the families you happen to
remember. This skill walks a fixed family list against a target and forces a
verdict on each, so the gaps are gaps you chose rather than gaps you missed.

Two kinds of row carry the deliverable. CONTRACT-SILENT: the input is reachable
and the spec does not say what happens, so whatever the code does today is now
the spec by accident. NOWHERE: the contract is clear and nothing tests it.

## Inputs

`/edgeledger <path>`, `/edgeledger <function or format name>`. Read the target
first. Reading is not optional and not delegable to a summary.

## Procedure

1. **Read the contract, then the implementation.** Signatures, accepted grammar
   or format, scaladoc, the error type. The contract is what a caller is
   entitled to; the implementation is what actually happens. Where they differ
   you have a finding before you start the walk.
2. **Walk `families.md` family by family.** For each family ask two questions:
   what input in this family can reach the target, and what does the contract
   say happens to it? A family that structurally cannot apply gets one line
   saying so and no rows - a target that takes no time value has no clock
   family. Do not skip a family because it looks unlikely; skip it only when
   it cannot apply.
3. **Emit the table.** One row per case, fields:

   - **case**: a concrete input or a precise shape. `""`, `-0.0`, a lone
     high surrogate `\uD800`. Not "an unusual string".
   - **family**: which section of `families.md` produced it.
   - **expected**: the behavior the contract specifies, quoted or cited. Use
     `CONTRACT-SILENT` when the spec does not say. That is a finding, not a
     blank - record what the code does today alongside it, marked as observed
     rather than promised. If part of the contract is out of reach (a spec you
     were told not to read, an external standard), do not claim
     CONTRACT-SILENT: use `OBSERVED-ONLY` and name what you could not check.
   - **covered by**: `file:line` of the test that exercises this case,
     `NOWHERE`, or `UNKNOWN` when the run's protocol has not yet allowed
     reading the tests.
   - **proposed test**: a name that states the expectation, so a reader can
     tell what red would mean.
   - For parse/print or read/write targets, asymmetric pairs (accepted on the
     way in, changed on the way out) are one row per direction, cross-linked,
     not one squeezed cell.

4. **Sort by severity**: within each contract class, a hang or corruption
   outranks a cosmetic acceptance quirk - contract status picks the tier,
   blast radius orders within it. CONTRACT-SILENT and OBSERVED-ONLY tiers
   first, then NOWHERE, then covered.

When a family multiplies against many sibling targets (nine numeric codecs),
pick representatives: the smallest, the largest, one floating, one arbitrary
precision - and say which siblings each represents. Enumerate a sibling
separately only where its behavior diverges from its representative.

## Rules

- **Evidence rule.** Every coverage claim cites `file:line`. Every NOWHERE
  names the searches that came back empty. "I did not find one" without the
  search is a guess. Hoist searches into one numbered list above the table and
  cite them by number; the same search backs many rows.
- **Null result per family is fine and is stated.** "Encoding: the target takes
  a byte array and never decodes - no rows" is a real output. A family with
  nothing to say beats a family padded to look thorough.
- **Proposed tests must be falsifiable.** For each, name the edit that would
  turn it red. If nothing would, cut it.
- **Stop at the boundary.** If the target delegates to code you did not open,
  say so and do not invent its edges.
- Line numbers drift. Cite the symbol name alongside the line.

## Anti-patterns

- **Combinatorial spam.** Every family crossed with every parameter is
  mechanical, not analytical. One row per case that a reader would agree is
  distinct behavior, not per cell of a grid.
- **Cases the type system forbids.** A null in a non-nullable position, a
  negative length behind a refined type. If the compiler rejects it, it is not
  an edge case.
- **Restating existing test names as discoveries.** Citing `roundTripsEmpty`
  as coverage is correct. Presenting it as something you found is not.
- **Tests that cannot fail.** `assert(parse(x).isRight || parse(x).isLeft)` is
  decoration.
- **Vague expectations.** "Handles it gracefully" is a refusal to read the
  contract. Name the return value, the error, or the exception.

## Output

The numbered search list, then the table sorted by severity, then one line per
family skipped as inapplicable with its reason. If a candidate case turned out
to be forbidden by the type system or already covered by an obvious test, drop
it and say so in one line - the drop list is how a reader tells restraint from
blindness.
