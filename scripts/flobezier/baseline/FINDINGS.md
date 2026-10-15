# FloBezier discrepancy inventory

The first file-inventory pass is complete; this is not a parity claim. Fixes are deferred.
The pinned source and download provenance are in `provenance.json`.
The library under comparison is Gleam commit
`e63197586b69f6db3f0d2896146bbad7459ef318` (3.1.1).

## Reference baseline

The unmodified normal upstream command was:

```sh
node node_modules/jest/bin/jest.js --runInBand --json --outputFile=/absolute/path/to/scripts/flobezier/upstream-full-suite.json
```

It passed **164 specification files / 326 tests**. The two Hausdorff experiments
are excluded by upstream configuration and were reviewed as source, not run.
They do not correspond to a public Hausdorff operation in this package.

`INDEX.md` and `inventory.json` distinguish this baseline from comparison
coverage. A file containing one compared operation is not marked fully covered.
In particular, coefficient, exact-arithmetic, boundless-root and fast-solver
assertions are not covered merely because a reference intersection call was
captured while their file ran.

## Current comparison counts

| Batch | Calls | Matches at diagnostic tolerance | Unresolved | Confirmed FB001 occurrences | Other dispositions |
| --- | ---: | ---: | ---: | ---: | ---: |
| Intersections | 3609 | 3496 | 32 | 3 | 78 |
| Numerical and affine | 14526 | 14437 | 4 | 0 | 85 |

The final 928-call batch is reported below separately because it adds a second
confirmed bug, FB007, rather than another occurrence of FB001.

The 32 unresolved intersection calls represent 24 distinct ordered input pairs.
The first two batches have five unresolved groups (FI002–FI006), not 36 confirmed
bugs; the final batch adds FI008. Other dispositions include contract differences and upstream rejected
inputs; they are not counted as passing matches.

## FB001 — confirmed overlap classification defect

See [the original analysis and two-target reproducer](FIRST_BATCH.md).
The line `[[1,1],[2,2]]` and quadratic `[[0,0],[3,3],[0.5,0.5]]`
have continuous overlap with non-monotone correspondence. Our overlap API returns
an empty success rather than its documented rejection, and the intersection API
returns `InternalOverlapClassificationInconsistency`.

The expanded intersection capture contains three occurrences of this existing
finding. The follow-up in [OVERLAP_INVESTIGATION.md](OVERLAP_INVESTIGATION.md)
confirms FI003 belongs to the same failure family. A candidate fix now passes
92 targeted tests on each target; it is not committed yet.

## FI002 — extra intersections beside shared tangent endpoints

Status: **documented numerical limitation, not a confirmed contract violation**.
Investigated on both targets; see [TANGENT_INVESTIGATION.md](TANGENT_INVESTIGATION.md).

There are 20 calls in
`bezier-bezier-intersection-shared-endpoint/shared-endpoint-intersection.spec.ts`
where every reference parameter pair is matched, but our solver returns extra
pairs near the shared endpoint. All returned pairs pass the independent
geometric residual check. That does not establish that they represent distinct
mathematical roots.

Representative call 1268 in `intersections-results.json`:

```text
A = [[11,40],[89,67],[-7,44]]
B = [[19,23],[185,90],[-7,44]]
reference = [(1,1)]
ours = [(0.9999993727743517,0.9999996863872628),
        (0.9999996854193223,0.999999842709683), (1,1)]
```

The current API explicitly permits several acceptable candidates for one
near-tangent contact. All 20 cases retain every reference root; the 23 extra
candidates cluster at shared endpoints and satisfy the distance tolerance.
The representative case has an independent algebraic proof of one exact root
in the parameter domain. Improving root isolation is optional numerical work,
not grounds for a broad deduplication threshold change.

## FI003 — folded collinear curve/curve overlap returned as isolated points

Status: **confirmed bug in the FB001 overlap classification family**.
See [OVERLAP_INVESTIGATION.md](OVERLAP_INVESTIGATION.md) for analytic ranges,
both-target reproduction, and a proposed fix.

Two geometries each occur three times in the general and fast-reference tests:
expanded capture calls 1/1994/2994 and 16/2009/2999.

```text
A = [[0,0],[1,1],[0.25,0.25]]
B = [[2,2],[0.5,0.5],[0.25,0.25],[-1,-1]]

A = [[0.1,0.1],[0.8,0.8],[0.2,0.2]]
B = [[1,1],[0.5,0.5],[0.3,0.3]]
```

Our point API returns six and four pairs respectively; the reference returns
two representative pairs. Do not interpret the reference endpoint count as the
required result for our point API. Continuous overlap should be assessed through
our own documented overlap/error contract.

## FI004 — almost collinear geometry at a scale below geometric tolerance

Status: **understood conditioning/tolerance limitation**, reproduced on both
targets. An invertible vertical scaling recovers the reference root; automatic
scaling would change the distance metric. See
[ALMOST_COLLINEAR_INVESTIGATION.md](ALMOST_COLLINEAR_INVESTIGATION.md).

Calls 12/2005/2997 share one pair of cubics whose y coordinates are about 1e-14,
while their x coordinates are of order one. FloBezier returns one certified
intersection; our solver returns nine approximate pairs, all passing the
geometric residual check, but none matching the reference parameters within
1e-7. Our default geometric tolerance is much larger than the y variation.
This is not automatically a breach of our contract or a demand for certified
precision. Full inputs are retained in the report.

## FI005 — coincident constant cubics return different parameter sets

Status: **unspecified constant-segment parameter convention**, investigated
on both targets. The reported pairs are geometrically valid; a canonical
representative is recommended alongside FI008. See
[CONSTANT_INTERSECTION_INVESTIGATION.md](CONSTANT_INTERSECTION_INVESTIGATION.md).

Calls 13/2006/2998 use two cubics with all four controls at `[1,1]`.
FloBezier returns representative parameters `(0.5,0.5)`; ours returns nine
parameter pairs, all evaluating exactly to that point. Determine the applicable
zero-length/intersection contract before considering a change.

## FI006 — default length fails on folded curves

Status: **confirmed avoidable convergence limitation**, reproduced on both
targets. Splitting at turning points resolves all four cases without increasing
the tolerance budget. See [LENGTH_INVESTIGATION.md](LENGTH_INVESTIGATION.md).

`global-properties/length/length-accuracy.spec.ts`, test
`should be accurate for degenerate curves (collinear / folded / lower order in disguise)`:

| Controls | Interval | Reference length | Our result |
| --- | --- | --- | --- |
| `[[0,0],[3,1],[1,1/3]]` | `[0,1]` | 2.7406406388125957 | `LengthMaxDepthReached` |
| same | `[0.25,0.75]` | 0.7642171012073585 | `LengthMaxDepthReached` |
| `[[0,0],[3,0],[-1,0],[2,0]]` | `[0,1]` | 2.7559289460184546 | `LengthMaxDepthReached` |
| same | `[0.25,0.75]` | 0.4434289460184544 | `LengthMaxDepthReached` |

The adapter uses `segment_between` followed by `measure.segment_length`, both
with their ordinary public behavior/defaults. These observations are JavaScript
only so far. No tolerance/depth adjustments or production fixes were made.
Unlike FB001's false empty success, this is an explicit bounded-computation
error; whether it merits a bug fix remains to be investigated.

## Comparison contracts

- Isolated intersections: one-to-one parameter matching within 1e-7, plus an
  independently evaluated geometric residual within 1e-9 plus a scale-based
  floating-point allowance. These are diagnostics, not newly promised accuracy.
- Numerical measurements: explicit diagnostic tolerances are in `numerics.mjs`.
  They do not attempt FloBezier's certified intervals or few-ulp guarantees.
- Nearest points: compare minimum distances, allowing different tied minimizers.
  Endpoint-excluding searches are separately recorded as a policy difference.
- Curve portions: compare evaluated geometry at five parameters, allowing the
  representation to differ for collapsed portions. This is sampled evidence,
  not a proof of polynomial identity.
- Curvature: negate FloBezier's sign to match our visual-left/y-down convention.
  NaN at zero speed corresponds to our explicit curvature error.
- Cusps: FloBezier's duplicate equal self-intersection parameters are distinct
  from our requirement for two arc-length-separated visits.
- Reversed length intervals: compare absolute length, because our reversed
  segment traversal still has nonnegative length.
- Rotated boxes: record the upstream orientation policy separately; our
  axis-aligned box comparison does not stand in for this operation.
- Affine transforms: convert radians to degrees and matrix element order;
  reflection uses our rotation/scale/composition API. Diagnostic matching does
  not establish upstream bit-for-bit identity for quarter-turn arithmetic.

All expanded comparisons are on JavaScript. Only FB001 has been reproduced
independently on Erlang as well. There were no production edits, native test
changes, release changes, or commits in this audit continuation.

## FB007 — closest-pair search overflows the JavaScript stack

Status: **fixed in the working tree; targeted tests pass on both targets**.
The follow-up reduced it to a unit
cubic/line, confirmed that case succeeds on Erlang, and identified non-tail
callback recursion in the projection-window collector. See
[the investigation](STACK_OVERFLOW.md). A disposable iterative trial succeeds
on the minimal case. The production control-flow fix is now implemented;
12 targeted tests pass per target, and the original JavaScript query completes.
The full suite was not run. Earlier audit reports retain the original failure.

Upstream file `simultaneous-properties/tolerance-zero.spec.ts`:

```text
A = [[100000,100000],[100001,100010],[100007,100003],[100010,100000]]
B = [[100000,100005.18996761437],[100010,100005.18996761437]]
```

`distance.segment_segment_closest_pair(A, B)` with defaults throws
`RangeError: Maximum call stack size exceeded`, rather than returning its
Result. This is the ordinary default call, not the upstream zero-tolerance
experiment. The reference default distance is approximately 0.00150249596;
its test also runs a tighter query, so that default value should not be adopted
as an exact geometric expected answer.

Reproducer: `node scripts/flobezier/closest-pair-stack-probe.mjs`.
Its expected current exit status is 1; the captured stack is in
`closest-pair-stack-probe.log`. This script imports the public API directly and
does not use the capture wrappers or comparison adapter. The stack reaches
`inspect_projection_window` and the recursive projection search in
`intersections.mjs`. No root-cause fix is proposed by this inventory.

## FI008 — zero-length line against a circle

Status: **confirmed zero-direction dispatch defect**, reproduced on both
targets, including an argument-order-dependent line/line result. See
[CONSTANT_INTERSECTION_INVESTIGATION.md](CONSTANT_INTERSECTION_INVESTIGATION.md).

`intersection/circle-bezier-intersection.spec.ts` uses the unit circle centered
at `[1,1]` and constant lines `[[1,1],[1,1]]` and `[[2,1],[2,1]]`.
The upstream results are respectively no intersection and one representative
parameter `0.5`. With the circle represented by two exact SVG semicircle arcs,
our segment intersection calls return `IndeterminateDirection` for both.
Four ordinary circle/curve calls in the same file match. No attempt was made
to replace the constant line with a different parameterization or hide its
error in the adapter.

## Completion of the remaining-file pass

All **61 previously pending files** now have a per-file review in
`remaining-review.json` and the index. The unchanged upstream batch passes
**61 files / 122 tests**, as does its instrumented run. The batch captures
**928 calls**: 873 match adapted contracts, one confirms FB007, two retain
FI008, and 52 have a recorded API/input difference. Calls are not tests.

The complete normal-suite index now has **68 files with selected operations
compared**, **42 reviewed contract differences**, and **54 screened arithmetic
or infrastructure files**. The two excluded experimental files remain separately
source-reviewed. There are no unreviewed files in the original 61-file queue.
This completes the first inventory pass, not exhaustive assertion parity:
helper calls do not cover every assertion in their enclosing file, and stronger
certified-precision requirements were not imported into our API contract.

Additional adaptation details:

- Algebraically identical overlapping curves: compare positive overlap endpoint
  correspondences with `overlaps.segment`; endpoint-only point contacts correctly
  yield no continuous overlap. All 722 captured calls match this adapted check.
- Subdivision by maximum length: compare the maximum-piece-length constraint and
  total length, not upstream dyadic split parameters or piece count.
- Flattening: compare a 1001-point sampled deviation check at the supplied
  tolerance, not the exact polyline vertices. This is sampled evidence only.
- Bounds: compare control-point boxes or extrema coordinates; certified root
  intervals and rigorous outward rounding remain outside the comparison.
- Hodograph and conversion: compare evaluated geometry/derivatives, not a new
  curve-object API or exact control-count requirement.

The broader initial findings remain open. No production fixes, new API options,
native regression tests, commits, or release changes were made.
