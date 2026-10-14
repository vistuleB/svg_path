# FI008 and FI005: constant-segment intersections

Investigated 2026-10-14 against `0d96855`. The convention below is now
implemented in the working tree and validated with targeted tests.

## Disposition

FI008 exposes a concrete dispatch defect: the zero direction of a constant
line is passed to an algorithm requiring a nonzero ray direction. This can
make the same intersection succeed or fail solely by swapping arguments.
The public segment-intersection entry point does not document a nonzero-length
precondition. The error is understandable inside the ray solver, but this
geometric query does not inherently require a direction.

FI005 exposes an unspecified parameter convention for constant segments.
All nine reported parameter pairs for identical constant cubics evaluate to
the same point exactly. They are not false roots, and FloBezier's single
representative `(0.5,0.5)` is not required by our current documentation.
However, the arbitrary finite inventory depends on polynomial degree and
solver sampling. It is unsuitable as a stable policy for an infinite set of
valid parameter addresses. Treat this as a behavior clarification to accompany
the FI008 fix, not nine incorrect geometric intersections.

## Reproduction on both targets

The circle has center `(1,1)`, radius 1. A semicircle from `(2,1)` to `(0,1)`
with positive sweep contains the tested interior point `(1,2)`.
Constant segments are represented as a line, quadratic, or cubic, with every
control point equal to the tested point.

| Point versus semicircle | Constant line | Constant quadratic | Constant cubic |
| --- | --- | --- | --- |
| Center (1,1) | IndeterminateDirection | empty | empty |
| Outside (3,3) | IndeterminateDirection | empty | empty |
| Arc endpoint (2,1) | IndeterminateDirection | 4 parameter pairs | 6 parameter pairs |
| Arc interior (1,2) | IndeterminateDirection | 4 parameter pairs | 6 parameter pairs |

Both argument orders reproduce these counts. The original FI008 full-circle
case can be checked by combining the two semicircles; the issue is already
visible in each individual segment query.

For two coincident constant segments at `(1,1)`:

| Pair | Point intersections | Overlaps | Encounters |
| --- | --- | --- | --- |
| Any pair containing a line | IndeterminateDirection | empty | IndeterminateDirection |
| Quadratic / quadratic | 4 pairs | empty | same 4 pairs |
| Quadratic / cubic (either order) | 6 pairs | empty | same 6 pairs |
| Cubic / cubic | 9 pairs | empty | same 9 pairs |

A stronger minimal example is a constant line P at `(1,1)` and ordinary line
L from `(0,1)` to `(2,1)`:

- `intersections.segment(P,L)` returns `IndeterminateDirection`.
- `intersections.segment(L,P)` returns one intersection at `(left_t,right_t)=(0.5,0)`.

Replacing P with a constant quadratic or cubic gives two representatives,
constant-side parameters 0 and 1, in both orders.

The probe runs 57 API calls per target: 24 constant-versus-arc queries,
27 queries across the 9 constant pairings using intersections/overlaps/encounters,
and 6 queries against an ordinary line. All success/error and candidate-count
signatures agree on Erlang and JavaScript.

## Cause

`segment_intersections_valid_options` dispatches on the first line it finds.
`line_segment_intersections` cannot form a support line from equal endpoints,
so it falls through to `line_segment_intersections_by_ray`. That function passes
`end-start=(0,0)` to `segment_ray_crossings_with`, whose direction validation
correctly rejects it. Reversing two lines can select a nondegenerate line as
the support instead, explaining the asymmetric success.

Constant quadratics/cubics enter the curve-pair search. Endpoint matching,
coordinate roots/projection, and candidate sampling provide several valid
parameter addresses. Parameter deduplication intentionally retains different
addresses rather than merging solely by geometric point. None of this chooses
a representative for a curve with infinitely many equivalent addresses.

Overlap documentation describes non-zero-length coincident intervals. A
constant segment has no positive geometric-length overlap, so an empty overlap
list is appropriate; its contact should be handled by the point query.
The internal sampled overlap routine also explicitly assumes nondegeneracy.

## Recommended behavior and implementation

Handle exactly constant polynomial segments before ordinary overlap/line/curve
solver dispatch. Detect equality of every defining point, not merely equality
of start and end, and do not use the geometric tolerance to collapse short but
nonconstant curves. Closed loops and retraced curves must retain their geometry.

Use `t=0` as a documented canonical address on the constant segment. This agrees
with the currently successful ordinary-line/constant-line case; there is no
need to adopt FloBezier's arbitrary choice of 0.5.

- Two constant segments: one representative `(0,0)` when their points satisfy
  the query's coincidence tolerance; otherwise no intersection.
- One constant segment: find all matching parameters on the other segment,
  pairing each with the constant segment's canonical 0. Preserve multiple
  visits on the nonconstant segment, including distinct closed-seam addresses.
- No continuous overlap for a point-like segment.
- Ensure `encounters.segment` shares the same handling; fixing only the public
  point wrapper would leave its internal point-search path inconsistent.
- Preserve existing option validation and final geometric certification.
- Do not reinterpret SVG arcs with degenerate radii/endpoints in this branch;
  their existing SVG normalization and DegenerateArc contracts are separate.

This requires no new types or options, but it does intentionally change the
number and parameters of results for constant curves. Document the policy and
test it explicitly. Suggested regressions include both orders, all polynomial
degrees, contact/disjointness, tolerance boundary, ordinary and closed curves
with multiple visits, encounters, and a short nonconstant curve that must not
be collapsed. See the implementation and validation record below.

## Commands and evidence

From `scripts/flobezier/probe`:

- `gleam run --target javascript -m constant_intersection_probe`
- `gleam run --target erlang -m constant_intersection_probe`

Results: `constant-intersections-javascript.log` and
`constant-intersections-erlang.log`. These are diagnostic probes, not a full
regression-suite run. Original FloBezier provenance is the pinned revision
recorded in the sibling TANGENT_INVESTIGATION.md report.

## Implementation and validation

Exactly constant polynomial segments now take a shared point-query branch
before line/curve dispatch. Every defining point must compare equal; short
nonconstant segments, closed loops, and folds remain nonconstant. The constant
parameter is 0.0. Matching parameters on the other curve are sorted and retained.
Constant pairs use one `(0,0)` representative when within tolerance, or none.

Overlap detection returns no positive-length intervals for constant polynomials,
while preserving arc validation. Encounters uses the same internal point-query
branch. Public documentation in intersections, overlaps, and encounters records
the convention. Options and final certification retain their existing checks.

Five tests in `test/svg_path_flobezier_constant_intersections_test.gleam` cover
all polynomial degree pairings, disjoint constants, arc endpoints/interiors and
noncontacts, line-query symmetry, closed-seam and folded-curve addresses,
noncollapse of a short line, tolerance boundaries, invalid options, and invalid
arc geometry. They are registered in the portable suite.

A standalone runner in `/tmp/svg-path-constant-targeted` ran the five new tests,
the four folded-overlap regressions, and all tests from the existing overlaps,
intersections, and encounters modules:

- `gleam run --target javascript -m constant_targeted`: 97 tests passed.
- `gleam run --target erlang -m constant_targeted`: 97 tests passed.

Logs: `/tmp/constant-tests-js.log` and `/tmp/constant-tests-erlang.log`.
No full suite or figure generation was run. Implementation and targeted validation are included with this report.
