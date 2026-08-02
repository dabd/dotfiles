---
name: fencing
description: Use before any edit that deletes, disables, bypasses, skips, or simplifies away existing behavior whose purpose is not obvious - guards, retries, sleeps, caps, magic numbers, special cases, protocol layers. This includes optimization requests that route around existing machinery. Recovers why the code exists from git history before you remove it.
---

# fencing

Chesterton's fence as a procedure: do not remove code until you know why it
was built. Answers three questions: who built this, against what, and is that
constraint still alive.

## Inputs

- `/fencing <file:lines>`, `/fencing <symbol>`, or a pasted snippet, or
- auto: the user (or you) is about to delete, simplify, or bypass code whose
  reason is not stated nearby. Run this BEFORE the edit, not after.

## Procedure

1. Locate: resolve the target to file and lines on the current checkout.
2. Archaeology, cheapest first; stop at the first source that states the
   reason:
   a. `git log -L<start>,<end>:<file>` - follows the lines through renames
      and rewrites. If the commit it lands on does not mention the target
      (a refactor that merely moved the line), fall through to
      `git log -S '<identifier>'` before concluding anything.
   b. The introducing commit: full message plus the rest of its diff (the
      sibling changes often explain the guard).
   c. Linked artifacts: PR (`gh pr view <n>`), ticket ids in the message.
      An unresolvable link (migrated repo, dead tracker) is not a dead end:
      record it as searched-and-unresolvable and let the verdict say so.
   d. Tests that would fail if the code were removed: name them; do not run
      them yet.
   e. Upstream provenance, when the fence is built from library APIs: read
      the documentation of the exact calls involved and search the
      library's docs and issue tracker for the combination. A transplanted
      idiom carries its reason in the upstream docs, not in your repo's
      history, and a whole pattern arriving in one commit with no local
      rationale is the signature of a transplant.
   f. Semantic-owner descent: the layer you call is rarely the layer that
      defines the behavior. The test is ownership, not topic: if you can
      state what the change alters but cannot point to code in front of
      you that defines that behavior, the definition lives in a lower
      layer - descend the delegation chain to its owner and read that
      contract before any verdict. (Cancellation scope, backpressure, and
      evaluation order are typical examples; the test, not this list,
      decides.)
3. Constraint liveness: is the original condition still true today? Check
   the dependency, platform, caller, or bug it guarded against on the
   current tree, not the historical one.
4. Verdict, exactly one of:
   - KEEP: constraint alive; cite it.
   - REMOVE: the reason is recovered and it no longer holds. Two shapes:
     the constraint expired (cite what expired and when), or it never
     existed - accidental duplication, dead on arrival (cite the
     introducing commit showing no reason was recorded).
   - REMOVE WITH EYES OPEN: no reason recoverable. Say so plainly, list
     what was searched (log, PRs, tickets, tests, including links that
     could not be resolved), and name the cheapest canary that would catch
     a regression: a test to add first, or a metric to watch after.

## Interaction contract (what a verdict does to the edit in flight)

This skill usually fires while an edit is already underway. The verdict
gates what happens next:

- Fast-path REMOVE: make the edit; state the recovered reason and its
  expiry in one line so the review trail carries it.
- KEEP: do not make the edit this turn, and do not hand over an
  apply-ready diff. Present the constraint with its citations and the
  concrete failure the edit would reintroduce, then stop. Proceed only on
  an explicit go given AFTER the verdict; instructions issued before it
  do not count, since they were given without this information.
- REMOVE WITH EYES OPEN: present what was searched and the canary. If the
  canary is cheap (a test to add), add it and proceed. If it is expensive
  (a load or soak run), stop and put the choice to the user.

The verdict leads the response; it is never buried under a diff.

## Fast path

Reason recovered in one blame and clearly dead or clearly alive: answer in
three lines or fewer and proceed with the edit. The full report is for
genuinely murky fences, contested verdicts, and callers who asked for the
trail.

## Evidence rule

Every claim cites a commit, PR, ticket, test name, file:line, or a named
upstream doc. "Probably legacy" is not a verdict. If the evidence is thin,
the verdict is REMOVE WITH EYES OPEN, not a confident guess.

Three priors that bound the verdict:

- Rare-variant prior: code using the marked variant of a common API (the
  Weak, Unsafe, uncancelable, the longer stranger name) is presumed
  deliberate. An unexplained rare variant never gets plain REMOVE: recover
  the variant's documented semantics first, and if the difference is
  load-bearing on this path, the verdict is KEEP.
- Replacement semantics: a verdict that endorses replacing API A with API
  B states the A-vs-B semantic difference from the library's own
  documentation, not from memory.
- Hot-path cap: on the hot path of the service's core function, "no reason
  recoverable" caps at REMOVE WITH EYES OPEN, and the canary must be a
  load or soak run, not a unit test.

## Anti-patterns

- Blocking trivial edits: renames, comment fixes, and imports whose removal
  cannot change what compiles need no fence check. Anything else with zero
  references still gets the fast path, not a skip: dead-looking code with a
  live reason is the whole point of this skill.
- Fencing your own fresh work: code introduced in the current session or the
  current unmerged change has no history to excavate; deleting it needs no
  fence check.
- History tourism: stop at the first commit that states the reason; the
  full lineage is not the deliverable.
- Verdict inflation: KEEP requires a live, named constraint. Reverence for
  old code is not a constraint.
