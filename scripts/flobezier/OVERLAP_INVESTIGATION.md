# FB001 and folded collinear overlaps

> Closure status (2026-10-15): Fixed and committed in `dd381a2`; final captured cases now follow the documented overlap error contract.
> The dated investigation below preserves the observations and intermediate status at that time.

Investigation date: 2026-10-14. Candidate fix implemented; not committed.

## Confirmed failures

FB001 was previously reproduced on both targets. The additional cases below
also reproduce on JavaScript and Erlang, in both argument orders.

A minimal quadratic has controls `(0,0), (4,0), (0,0)`:
`x(t) = 8t(1-t)`. Its image is exactly `[0,2]`, with a turn at `t=1/2`.

| Line x interval | Correct geometric relationship | Current point result |
| --- | --- | --- |
| [1,3] | Continuous overlap [1,2]; nonlinear parameter correspondence | InternalOverlapClassificationInconsistency |
| [2,3] | One contact, quadratic t=1/2 and line t=0 | InternalOverlapClassificationInconsistency |
| [3,4] | Disjoint | InternalOverlapClassificationInconsistency |

All three overlap calls return `Ok([])`. This is wrong for the first:
our documented result should be `NonAffineOverlapCorrespondence`.

FI003-a: the first quadratic has scalar coordinate `2t - 7t²/4`,
range `[0,4/7]`. The other cubic monotonically covers `[-1,2]`.
FI003-b: the first quadratic has coordinate `0.1 + 1.4t - 1.3t²`,
range `[0.1,31/65]`. The other quadratic monotonically covers `[0.3,1]`.
Both therefore have positive-length continuous overlap. Returning six/four
isolated pairs is a bug under our contract, regardless of the reference's
choice of representative intersection pairs. They should reject unsupported
non-affine correspondence.

## Causes

`internal/overlap_detection.gleam` constructs overlap candidates from original
segment endpoint projections. Its documented assumption that every overlap
boundary is an input endpoint fails for retraced collinear curves: an interior
turning point can bound the shared image. FB001 and FI003-b produce zero-span
candidate pairs on one input and discard them. FI003-a proposes an interval
that misses the interior excursion; the sampled containment test discards it.

Separately, `intersections.gleam` uses `segment_projection_overlaps_line` on
control points as evidence of actual positive-length overlap. Their projected
range is only a bound. This causes the contact-only and disjoint false errors
above: the quadratic control reaches 4, whereas the actual curve reaches 2.

## Recommended implementation

Restrict the initial fix to collinear polynomial segments (lines, quadratics,
and cubics). Compute scalar derivative roots and monotone parameter intervals,
then compare their actual image intervals. Retain original segment parameters
and use the existing affine-correspondence checks on each shared interval.
Unsupported nonlinear correspondence must return the documented error.

Use actual image ranges in the line/curve classification too. Distinguish
positive-length overlap from contact and disjointness; contact needs its
original parameter pair(s). Do not flatten the curves or substitute lines.
Preserve valid affine correspondences, including reversal and degree elevation;
do not reject a segment solely because it retraces. Identical retraced curves
also expose an empty-overlap result and need coverage when implementing.

Before adopting: regressions for all three minimal cases, both FI003 geometries,
both argument orders, valid affine overlap, and identical/reversed folded
curves. Include vertical and translated/scaled variants. Existing closed-curve
endpoint-alias tests must remain valid. Numerical collinearity and parameter
interval tolerances need particular care. See validation below.

## Diagnostic commands and evidence

- `node scripts/flobezier/overlap-investigation.mjs`: 8 fixtures in both
  orders, 16 diagnostic rows; results in `overlap-investigation.json`.
- From `scripts/flobezier/probe`:
  `gleam run --target erlang -m folded_overlap_probe`: 5 fixtures in both
  orders; output in `folded-overlap-erlang.log`.

These are diagnostic probes, not passing regression tests. No full suite run.

## Implemented fix and validation

The detector now adds collinear polynomial turning-point projections to the
candidate boundaries. Existing correspondence checks still decide whether a
mapping is affine. Conflicting folded traversal maps produce the documented
NonAffineOverlapCorrespondence error instead of being discarded as empty.

Line/curve point classification now compares actual endpoint/extremum values.
Contact prefers known boundary parameters over ill-conditioned tangent root
refinement. The line/line branch retains its existing implementation.

Four new tests in `test/svg_path_flobezier_overlap_test.gleam` cover FB001,
both FI003 inputs, quadratic and cubic folds, both argument orders, horizontal
and vertical directions, translation and scales 0.01/1/1000, contact,
disjointness, conflicting identity folds, and valid affine/reversed overlaps.
The module is registered in the portable suite.

A temporary standalone runner at `/tmp/svg-path-overlap-targeted` ran all tests
from the new module and the existing overlaps, intersections, and encounters
modules. Exact commands, run in that directory:

- `gleam run --target javascript -m overlap_targeted`: 92 tests passed.
- `gleam run --target erlang -m overlap_targeted`: 92 tests passed.

Logs: `/tmp/overlap-js.log` and `/tmp/overlap-erlang.log`.
No full suite or figure generation was run. A root JavaScript build was
unsuitable because the root test tree includes Erlang-only figure I/O; the
standalone runner builds and tests the dependency correctly on both targets.
