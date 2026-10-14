# FI006: length integration across folds

Investigated 2026-10-14 against production commit `dd381a2` (subsequent commit
`36d812f` changes audit documentation only). Production fix implemented and validated with targeted tests.

## Disposition

Confirmed avoidable convergence limitation, with a successful candidate remedy.
This is an explicit `LengthMaxDepthReached` result under a bounded numerical
API, rather than an incorrect length returned as success. It nevertheless
merits improvement: elementary folded curves fail at the default settings.

The four recorded FloBezier cases fail on both Erlang and JavaScript, and also
fail when their traversal direction is reversed. Defaults use tolerance 1e-9
and maximum depth 20. At depth 32 all four succeed. Depth 24 succeeds only for
the partial quadratic.

| Curve / original interval | Default | Split at turns (default depth) | Split at turns (depth 1) |
| --- | --- | --- | --- |
| Quadratic / [0,1] | depth error | 2.7406406388125957 | same |
| Quadratic / [0.25,0.75] | depth error | 0.7642171012073585 | same |
| Cubic / [0,1] | depth error | 2.7559289460184546 | same |
| Cubic / [0.25,0.75] | depth error | 0.4434289460184544 | same |

The table is identical on both targets. Splitting divides the original absolute
tolerance by the number of pieces; it does not increase the total budget.

## Geometry and independent lengths

Quadratic controls: `(0,0), (3,1), (1,1/3)`.
In ideal rational arithmetic its x coordinate is `6t - 5t²`, and its y
coordinate is x/3. Its turn is at t=3/5. Length is total variation of x
multiplied by sqrt(10)/3: 2.6*sqrt(10)/3 for the whole curve and
0.725*sqrt(10)/3 for the subinterval. Binary64 storage of 1/3 perturbs exact
collinearity by roundoff; the analytic values still provide more than enough
accuracy for the 1e-9 comparison.

Cubic controls: `(0,0), (3,0), (-1,0), (2,0)`.
Its x coordinate is `9t - 21t² + 14t³`; its turns are
`(7-sqrt(7))/14` and `(7+sqrt(7))/14`. Summing absolute x differences at the
interval endpoints and included turns independently gives the two lengths.

After extracting the middle subinterval with `segment_between`, local turn
parameters become 0.7 for the quadratic and approximately 0.122035526990773,
0.877964473009227 for the cubic.

## Cause

`adaptive_segment_length_between` in `internal/query.gleam` starts one adaptive
Simpson integration over the entire requested parameter interval. Its loop
bisects the interval and halves the allocated tolerance at each level.

At a reversal, speed is the absolute value of a signed polynomial velocity.
The resulting kink is generally not aligned with a dyadic subdivision boundary.
The integrator keeps subdividing the interval containing it until depth runs
out. For the whole quadratic, the final failing local error estimate is about
1.28e-12, but the recursively allocated local tolerance has already shrunk far
below the original 1e-9. This is consistent with the current allocation scheme;
it is not evidence that the total global error exceeded 1e-9.

Splitting at each turn leaves smooth speed on each piece. On these collinear
inputs, speed on each piece is a polynomial of degree at most two, making
Simpson integration exact in real arithmetic. Even depth 1 therefore succeeds.

## Recommended implementation

Prepartition polynomial length integration at coordinate derivative roots,
then integrate each interval with a share of the original tolerance budget.
The union of x and y extrema includes every true zero-speed parameter without
requiring an approximate-collinearity decision. Extra splits at ordinary
coordinate extrema are harmless geometrically, though their runtime cost
should be measured. Existing Bezier projection-extrema helpers supply roots.

Implement this in the shared `adaptive_segment_length_between` path, on the
original segment and requested interval, so length inversion and partial
length queries benefit too. Keep arcs on their existing path. Do not replace
curves with lines, globally increase max_depth, or loosen tolerance.

The probe slices curves through the public API to test the idea without editing
production code. A production implementation should preserve original parameter
intervals, deduplicate interior split parameters, retain option validation and
error behavior, and account for the total error budget. Validate translated,
scaled, reversed, zero-length and near-collinear curves, regular curves, and
length-inversion callers. The candidate implementation below follows this approach.

## Reproduction

From `scripts/flobezier/probe`:

- `gleam run --target javascript -m length_probe`
- `gleam run --target erlang -m length_probe`

Recorded in `length-javascript.log` and `length-erlang.log`. Each command checks
four fixtures with default options, four explicit depths, two split-integration
variants, and reversed traversal (32 diagnostic results per target).
These are diagnostic probes, not a full regression-suite run.

## Candidate implementation and tests

`internal/query.gleam` now partitions the requested original parameter interval
at the union of x/y Bezier projection extrema, removing duplicate split
parameters and dividing the tolerance equally among the resulting intervals.
The existing Simpson integrator and max_depth apply within each interval.
Arc behavior, input validation, and depth-exhaustion errors are retained.
`measure.gleam` documents the partitioning.

Five new tests in `test/svg_path_flobezier_length_test.gleam` cover the four
original failures, reversed traversal, depth 1, scale/translation/axis changes,
length inversion on a returning branch, constant geometry, and near-collinear
geometry. The module is registered for both portable targets.

A standalone runner in `/tmp/svg-path-length-targeted` ran those five tests and
35 existing length-related tests from `svg_path_geometry_test.gleam`, including
arcs, error handling, inversion, subdivision, and subpath/path operations:

- `gleam run --target javascript -m length_targeted`: 40 tests passed.
- `gleam run --target erlang -m length_targeted`: 40 tests passed.

Logs: `/tmp/fi006-tests-js.log` and `/tmp/fi006-tests-erlang.log`.
No full suite or figure generation was run.

### Local JavaScript timing sample

`/tmp/fi006-benchmark.mjs` compared the previously compiled dd381a2 dependency
in `/tmp/svg-path-overlap-targeted` with the current dependency in
`/tmp/svg-path-length-targeted`. After 100 warm-up calls, eight alternating-order
rounds of 1000 calls were measured. Values below use the upper middle sorted
round, in milliseconds per 1000 calls:

| Input | Before | Candidate |
| --- | ---: | ---: |
| Monotone quadratic | 53.48 | 77.77 |
| Arch quadratic | 411.21 | 408.19 |
| S cubic | 2530.61 | 2416.09 |
| Monotone cubic | 165.64 | 149.57 |

This is a small local timing sample, not a general performance guarantee.
Computing extrema can add overhead for cheap inputs; partitioning can reduce
adaptive work on others. The observed quadratic overhead is about 24 microseconds
per call. No change to the public options or tolerance budget is required.
