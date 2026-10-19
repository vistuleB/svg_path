# Endpoint and Boolean triage — 2026-10-18

> Classification corrected by [BOOLEAN-CONTRACT-TRIAGE.md](BOOLEAN-CONTRACT-TRIAGE.md).
> The outside-input witnesses are real, but arc interior displacement is an
> explicitly documented consequence of endpoint reconstruction. They are not,
> by themselves, confirmed bugs under the current CSG contract.

Native source: `090f8e63`. Classification only; no production modifications,
permanent regression additions, commits, or F# work.

## Arc endpoint matching uses a stricter tolerance than the caller

> Follow-up: ENDPOINT-REPAIR-EXPERIMENT.md revises the bug classification. The
> blanket caller-tolerance change conflicts with FL006, and endpoint completeness
> within tolerance is not explicitly promised. The observations below remain valid.

CC01751, CC01752 and CC01753 are three presentations of the same near-coincident
arc endpoint pair. Their endpoint gap is 1.4068028429806625e-12.

`elizabeth_beam_with_endpoint_seeds` calls `elizabeth_search_tolerance`, then
passes that stricter value to `elizabeth_endpoint_candidates`. For these arcs
the value is 8.01604638630139e-13, versus the caller's default 1e-9. Directly
calling the unchanged `overlap_detection.point_parameters` with the public
1e-9 finds parameter 1 (or 0 for reversed traversal). Calling the same matcher
with the internal tolerance finds nothing. The public intersection returns empty.

`probe-endpoint-tolerance.mjs` and `endpoint-tolerance.json` record both calls,
computed search tolerance, and a translated-input control (also empty).

Disposition: native endpoint-coincidence tolerance inconsistency. The internal
residual target is appropriate for refining roots, but currently also narrows
which approximate endpoint coincidences are admitted. This is not evidence of
an exact mathematical crossing being missed: the supplied endpoints differ.
The public option is documented as the path-coordinate distance for geometric
coincidence tests. Keep this distinction in any future fix/regression. Polynomial
normalization already preserves original-metric endpoint matching; arc handling
should be examined alongside it. No repair attempted in this batch.

## Two simple XOR families: different contour decomposition

Representatives CC00666 (`rectangle_over_half_of_circle`) and CC00685
(`rectangle_slicing_circle`) return two contours: an outer union contour and a
reversed intersection contour. Cavalier instead returns three/four separate
components. Under Nonzero fill these descriptions represent the same XOR region.

Evidence in `boolean-triage.json`:

- Serialized output walks identify the union outer boundary and reversed overlap
  boundary. Serialization is diagnostic and rounded; calculations use full precision.
- The first case has signed output area 5000, agreeing with the elementary formula
  circle area + rectangle area - twice half-circle area.
- The second has signed area 79.76781624589782, agreeing with the sum of absolute
  component areas captured upstream (within floating rounding).
- 961 off-boundary sample points per case agree with an independent analytic
  circle/rectangle XOR predicate, with zero mismatches. These samples alone are
  not a general boundary-equivalence proof; the explicit simple output walks and
  Nonzero union-minus-intersection construction explain these two cases.

The original per-contour comparator intentionally flags these differing layouts.
Do not generalize this disposition to the other XOR fixtures without inspection.
Only these two representatives were checked in this batch; related orientations
are not independently closed here.

## Boolean geometry displacement: overlapping pill-shaped ends (reclassified)

Checked **all 35 baseline `And` property discrepancies**, spanning nine upstream
fixture names and several operand orientations/orders. Every fresh result has
sampled output boundary points outside at least one input by more than 1e-6.
The largest measured distance is approximately 4.7181e-4. An exact mathematical intersection cannot contain geometry outside either
operand, but our documented reconstruction contract allows this interior arc
displacement. The initial bug classification was premature; see the correction.

Independent check for 14 records whose first input is a straight capsule:
its filled region is the radius-r neighborhood of a finite centerline segment.
Ordinary point-to-line-segment distance minus r agrees with the native outside
distance. This check does not use the upstream Boolean result or native CSG.

Concrete representatives:

- CC00797: output boundary point approximately
  `(12.768772323098753, 10.43318518960098)` lies 0.00025160312836936 outside
  the straight input capsule (independent calculation).
- CC00854: output boundary point approximately
  `(28.27004258319665, 20.801788192132616)` lies 0.00026728807355747 outside
  the straight input capsule. Other samples lie about 0.00047181 outside
  the second input.

`probe-boolean-triage.mjs` records output arcs/centers, signed areas, witness
parameters/points, input classification and distance, independent capsule checks,
and inset witness classification when the analytic capsule check is available.
The report is `boolean-triage.json` (37 records: two XOR and 35 intersections).
All 42 inset witnesses tested are strictly Inside the output and Outside the
first input; they remain outside the independently calculated capsule. Thus the
failure affects filled regions, not just numerical boundary classification.

Output arc centers differ from the corresponding input cap centers by around
1e-4 in the representatives, although both input caps have almost coincident
centers. This is a useful diagnostic, not yet an established root cause.
Investigate arc splitting, endpoint adjustment and reconstruction before proposing
a repair. Do not assume all 35 records necessarily share one implementation cause.

## Reproduction and remaining work

```sh
node scripts/cavalier/probe-endpoint-tolerance.mjs > scripts/cavalier/endpoint-tolerance.json
node scripts/cavalier/probe-boolean-triage.mjs > scripts/cavalier/boolean-triage.json
```

Use the current JavaScript dependency build in `test_portable`. The probes call
production functions unchanged. No full suite rerun was needed for diagnostic
scripts/docs. Baseline raw reports remain untouched.

Next: classify the remaining Boolean difference/XOR cases and arrangement errors,
then offset construction/collapse cases and coverage gaps. Keep confirmed repair
candidates separate from unresolved comparisons. F# remains deferred until the
Gleam audit is complete.
