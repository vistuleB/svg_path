# Long-path JavaScript stack overflow investigation

Subsequent status (2026-10-14): the [construction/closure fix](LARGE_CONSTRUCTION_FIX.md)
has passed the full release suite. Tokenizer and command-dispatch recursion
were subsequently fixed in `7ddb2fc` and `256c5e1`, with portable regressions and
full release validation. See [the current audit index](README.md).
The investigation below describes the earlier baseline and isolated experiments.

Investigation only. Library sources were not changed; no commit was made.
Candidate changes were compiled in `/tmp/svg-path-stack-investigation` with
Gleam 1.18.1 and tested using Node 24.10.0. The candidate patch is saved as
`stack-construction-candidate.patch` for review; it is not applied to the repo.

## Confirmed construction cause and candidate

Every endpoint policy, including Strict, passes through
`custom_reconcile_segments` in `src/svg_path.gleam`. Its recursive step follows
`use replacement <- result.try(...)`. Generated JavaScript executes that step
inside the `result.try` callback, retaining a stack frame per boundary. The
function has a generated loop, but this branch calls the function again instead
of advancing that loop. Point-to-line creation and final continuity checking
already compile to loops and are not the source of this overflow.

Replacing this one `use` with explicit `case Error / Ok` leaves the recursive
call directly in tail position. The compiler then emits loop-variable updates.
In the isolated build this handles 100,000 segments with all six built-in
policies and custom policies. A custom bridge replacement yields 199,999 edges;
a custom policy deleting pairs returns the same empty-subpath result as the
small-input control. Custom callback first/last/closing flags remain correct.

Late invalid inputs now return the documented `Discontinuous` errors rather
than overflowing first. The 100,000-edge late gap reports indices 99998/99999;
a malformed last custom replacement reports shifted indices 99997/99998.

## Closure has an independent overflow

After correcting reconciliation, `subpath_polygon` still crashes in `split_last`.
That helper recursively obtains the tail result and then prepends each earlier
item, so it consumes stack proportional to path length. Its current only external
call site is closed-subpath endpoint reconciliation.

A reversed accumulator and a final `list.reverse` make it directly tail recursive.
With both changes in the isolated copy, the 100,001-edge polygon succeeds too.
No endpoint policy, validation rule, source ordering or public type needs to change.

## Long SVG parsing has two more recursion cycles

The public `parse.path` call on 10,000 explicit `L` commands fails before endpoint
construction, in the mutual recursion between `tokenize_loop` and its command /
number / comma helpers. Fixing constructor and closure recursion does not help it.

To isolate later stages, the temporary generated parser module exported its
private token constructors and parser entry point. Feeding it valid prebuilt
tokens bypassed tokenization. 100 commands succeeded; 10,000 still overflowed.
The captured stack repeats `parse_line_loop -> parse_tokens -> parse_command ->
parse_line -> parse_line_loop`, confirming a separate command-dispatch cycle.
A tokenizer-only fix therefore would not complete the parser repair either.

These are additional manifestations of unsafe recursion on long inputs, not
errors caused by coincident geometry. Mutual tail calls are safe on Erlang but
are not turned into JavaScript loops by this generated code.

## Recommended implementation scope

1. Fix reconciliation and closure together with the two small structural rewrites.
   Add cross-target regressions for long open and closed paths, late errors, and
   custom replacement/context behavior, then run the release suite.
2. Repair the parser separately: tokenize using one driving loop whose helpers
   return the next state, and make command handlers return state/remainder to
   one dispatcher rather than recursively calling it. Preserve source locations,
   implicit commands, comma rules, compact arc flags and malformed-input errors.
   Test both explicit repeated commands and implicit numeric runs. This is a
   larger control-flow change, not an API redesign.

Do not increase JavaScript stack size or add an arbitrary public path-size limit
as a substitute for these fixes. Additional arbitrary operations on very large
paths were not exhaustively tested by this investigation.

## Evidence and reproduction

`investigate-stack-overflow.mjs` runs 13 scenarios at 100, 10,000 and 100,000
segments: six built-in policies, custom identity/context, late gap, invalid
custom replacement, polygon, parsing, custom bridge and custom pair deletion.

- `stack-overflow-baseline.json`: current library, 39 probes.
- `stack-overflow-candidate.json`: reconciliation-only experiment, 39 probes.
- `stack-overflow-closure-candidate.json`: both construction rewrites, 39 probes.
- `stack-overflow-parser-stages.json`: private-entry diagnostic, 2 probes.
- `stack-investigation-validation.json`: semantic comparisons and source check.

All 13 small-input scenarios have identical results in both candidate builds
versus baseline (26 comparisons, excluding timings and stack strings).
Both larger sizes behave as expected after the construction/closure changes,
except parsing, which remains independently broken. Runtime thresholds are
machine-dependent; these counts are samples, not promised limits.

```sh
# Build the original test_paperjs package first, then:
node scripts/paperjs/investigate-stack-overflow.mjs \
  test_paperjs/build/dev/javascript /tmp/stack-baseline.json
# The second argument can also point to an isolated candidate library build.
```

The full test suite was not run on the experimental copy. The successful
large-input probes establish a viable candidate, not production acceptance.
