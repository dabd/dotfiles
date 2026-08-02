# Edge-case families

Walk these in order. Each section gives the definition and signature cases.
The examples are prompts, not a checklist to copy: the target decides which
of them are reachable.

## empty / boundary / duplicate

Inputs at the edge of a collection, a range, or a key space, and inputs that
repeat where uniqueness may be assumed.

- the empty input: `""`, an empty array, a zero-element record, no arguments
- one element, and the element exactly at an inclusive or exclusive bound
- the same key twice: duplicate fields, repeated flags, a value equal to a
  sentinel the code uses to mean absent

## encoding

Text that is valid as a sequence of code units but not as the thing the code
assumes text is.

- unpaired surrogates: a lone `\uD800`, a low surrogate with no high partner
- normalization: `é` as one code point vs `e` plus a combining accent, where
  equality or key lookup is involved
- a BOM at the start of input, and locale-dependent casing (`toUpperCase` on
  `i` under a Turkish locale)

## numeric

Values where the arithmetic type stops behaving like the mathematical one.

- zero and negative zero, where `-0.0 == 0.0` but their bit patterns and their
  renderings differ
- infinities and NaN, including NaN failing every comparison including its own
- min and max of the type, overflow on negation (`Int.MinValue`), and precision
  loss at the boundary: `9007199254740993`, a long that no double represents,
  a decimal whose shortest round-trip repr is not its literal

## concurrency / reentrancy

Two callers, or one caller arriving again before the first returns.

- shared mutable state touched from two threads: a cache, a counter, a builder
- a callback that calls back into the API that invoked it
- an object documented as immutable or thread-safe whose internals are not

## retry / partial failure

The operation runs twice, or stops halfway.

- retry after a failure whose effect already landed: is the operation idempotent
- failure between two writes that must agree, leaving a torn state
- a partially consumed input: a stream that ends mid-token, a truncated payload

## clock

Anything reading time, or ordering by it.

- timezone and DST: a local time that occurs twice, and one that never occurs
- monotonicity: wall-clock going backwards under NTP, durations measured across
  the jump
- epoch extremes: year 1970 and beyond 2038, negative instants, leap seconds

## size / scale

Inputs whose size, not content, is the problem.

- huge: an input larger than memory, a string longer than `Int.MaxValue` bytes
- deep nesting: recursion depth that overflows the stack before it hits any
  configured limit
- zero-size where a positive size is assumed: a zero-length chunk, an empty
  batch, a zero-count loop bound

## platform divergence

The same source compiled or run somewhere else behaves differently.

- number representation: JS has one number type, so `Long` and boxed numerics
  collapse and integer identity is lost above 2^53
- string and stdlib APIs: `toUpperCase` locale behavior, regex flavor,
  `String.format`, and stdlib pieces absent on a platform (`java.time` on some
  targets)
- parsing and printing differences: what `parseDouble` accepts, how a float
  renders, and undefined behavior that only one runtime exhibits
