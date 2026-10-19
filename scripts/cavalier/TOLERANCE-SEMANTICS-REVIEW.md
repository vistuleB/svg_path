# Intersection tolerance: implementation review — 2026-10-19

Investigation only. No production behavior changes or commits.

## Concrete finding: representation changes the answer

Tolerance 1e-9; first straight edge `(0,0)` to `(1,0)`; second straight edge
`(1+1e-10,1e-10)` to `(1+1e-10,1)`. The finite edges do not intersect.

| Representation | Result |
| --- | --- |
| Line / Line | One near-endpoint candidate |
| Line / straight quadratic or cubic | One near-endpoint candidate |
| Straight quadratic or cubic / Line | One near-endpoint candidate |
| Straight quadratic / straight quadratic | Empty |
| Straight cubic / straight cubic | Empty |
| Straight quadratic / straight cubic (either order) | Empty |

The quadratic controls are exact midpoints on the straight edges. Thus even
without cubic degree-elevation rounding, geometrically identical inputs take
different endpoint acceptance paths. The endpoint candidate is within caller
tolerance and passes certification; this is not an error-bound violation.
Both Erlang and JS reproduce the line/quadratic contrast.

Exact-contact controls return the endpoint for all nine type combinations.
A gap of 2e-9 returns empty for all nine. The 29-case JS record also includes:

- Two distinct constant segments 1e-10 apart: one candidate.
- Two parallel lines 1e-10 apart over their entire length: `OverlappingSegments`.

## What the implementation actually does

| Location | Role of tolerance |
| --- | --- |
| `certify_segment_intersections_loop` | Reported point must be within caller tolerance of each evaluated curve point. |
| `line_segment_intersections_by_ray` | Endpoint projection within caller tolerance is itself admitted as a candidate. |
| `segment_intersections_valid_options`, constant cases | Proximity within caller tolerance can directly create a candidate. |
| `elizabeth_beam_with_endpoint_seeds` and original-metric polynomial seeding | Endpoint matching uses a much stricter internal accuracy/roundoff threshold. |
| `overlap_detection.collinear_parameters`, overlap precheck | Caller tolerance participates in deciding approximate coincidence/overlap. |
| `insert_path_intersection` | Caller tolerance groups already-found spatially close results. |

The public tolerance therefore does more internally than final error checking.
A common acceptance bound remains true, and proximity is not a universal
sufficient condition. But a stronger claim that proximity *never* creates a
candidate would be false. Exact algebraic incidence is not promised either.

## What follows

The user's necessary-but-not-sufficient interpretation is a coherent common
contract. It does not resolve how aggressively each solver should propose
candidates. Broadening all endpoint matching to caller tolerance is not merely
an accuracy improvement: the FL006 experiment demonstrates changed near-contact
inventory, while retaining the genuine crossing.

A concrete next design target is consistent endpoint candidate handling for
identical geometry represented as lines or Beziers. Separate the numerical
endpoint-recognition rule from the public final acceptance bound internally;
this does not inherently require a new public option. Any experiment must keep
exact shared-endpoint recovery, check both representations and reversed paths,
and retain the FL006 interior-crossing regression. Tightening line matching may
remove useful existing candidates; widening curve matching already conflicts
with FL006. Neither change is justified solely by the bound contract, and neither
is implemented here.

Overlap recognition and path-result grouping are further uses of tolerance;
they should not be silently changed as part of endpoint work. The present
examples establish representation-sensitive behavior, not proof that either
answer violates the documented bounded-search contract.

## Evidence

- `probe-tolerance-semantics.mjs`, `tolerance-semantics.json`: 27 pair cases and
  two constant/overlap checks on the ordinary native JS build.
- `probe/src/tolerance_semantics_audit_probe.gleam`,
  `tolerance-semantics-erlang.log`: five corresponding native Erlang checks.
- `ENDPOINT-REPAIR-EXPERIMENT.md`: rejected blanket widening and FL006 evidence.

No full suites rerun: production behavior was unchanged in this investigation.
