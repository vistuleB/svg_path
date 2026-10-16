# Twelve formerly blocked comparisons

Follow-up: [FL006 investigation](FL006-INVESTIGATION.md) identifies search-budget
loss for the full arc pair. A temporary ranking improvement recovers that
crossing; the default Boolean discrepancy also involves a separate short-pair
overlap classification and remains open.

Implementation: `2a2f94a`. Production geometry was not changed for this replay.
The original captures and strict-adapter results remain unchanged.

## Adapter policy

`continuity-adapter.mjs` makes adjacent endpoints exactly equal only when their
separation is at most 1e-6 path-coordinate units (the audit's existing comparison
tolerance). Larger gaps reject conversion. Every adjustment is recorded, including
whether it belongs to the left input, right input, or reference output.
Two policies are tested independently: move each previous end to the next start,
or move each next start to the previous end. Radii, sweep flags and arc rotation
are retained. This is an endpoint displacement bound, not a general bound on
arc-interior displacement. Captured objects are not mutated, and the library's
exact-continuity constructor is unchanged. The ordinary comparison adapter stays
strict unless this opt-in adapter is supplied.

The largest actual input adjustment is 7.28e-13. The largest reference-output
adjustment is 1.86e-8 (call 4296). These sizes and both snapping directions are
recorded in `remaining-continuity-replay.json`.

## Results

All 24 individual runs (12 calls × two policies) pass the existing area and
13×13 containment-grid comparisons: 4,056 checked points, no boundary exclusions
or membership mismatches. Additional bidirectional boundary checks evaluate five
points per segment and measure their distance to the other boundary: 5,970
samples, with no distance-query errors. These remain sampled checks, not certified
Hausdorff bounds or proof of full topology equivalence.

Eleven individual calls pass the boundary check within 1e-6. Call 4295 does not:
its maximum sampled discrepancy is about 3.68e-6 in either adapter policy.
The permissive area/grid comparison alone would have missed this.

| Calls | Result |
| --- | --- |
| 3115 | Sampled geometry matches; boundary discrepancy about 1.3e-13. |
| 4278–4282 | Sampled geometry matches; boundary discrepancies below 1.6e-12. |
| 4291–4294 | Sampled geometry matches; boundary discrepancies below 6e-14. |
| 4295 | FL006: missed arc intersection; four output arcs instead of the reference's five, boundary discrepancy about 3.68e-6. |
| 4296 | Individual captured-input comparison matches; boundary discrepancy below 9.4e-9. Chaining our previous output carries FL006 forward. |

`generate-continuity-erlang.mjs` generates exact reconciled primary-policy fixtures
for all twelve calls. The standalone Erlang replay succeeds for every Boolean
query and reproduces the area/segment observations and empty arc-pair result;
see `remaining-continuity-erlang.log`. The full sampled boundary/grid sweep above
was run on JavaScript, not duplicated on Erlang.

## Chained upstream fixtures

The two original multi-operation tests were also replayed by passing each native
output into the next native operation, instead of substituting the captured
upstream intermediate geometry. Both adapter policies were checked.

- Issue #2 (4278–4282) ends with one contour and six segments, matching upstream
  structural counts. Area and sampled membership match at every step.
- Issue #3 (4291–4296) retains the discrepancy introduced at 4295. Its final native
  result has one contour and six segments rather than upstream's seven; the area
  difference remains about 8.6e-8. The original test's edge-count assertion is
  therefore not matched. This is recorded, not hidden by the coarse geometry pass.
- The orientation sign differs under the libraries' contour conventions; these
  EvenOdd comparisons do not assert the same serialized direction or edge order.

See `probe-continuity-chains.mjs` and `remaining-continuity-chains.json`.

## FL006: confirmed missed intersection

The relevant pair is a short circular arc of radius 84.49938828627135 near
(59.75,59.75), and a quarter-circle of radius 85.20624291591454 centered at
(120,120). Exact endpoints and flags are in `remaining-continuity-4295-pair.json`.

An independent 80-digit Decimal calculation reconstructs each supporting circle
from the SVG endpoints/radius, intersects the circles, and checks arc membership.
One root lies strictly inside both arcs:

- point approximately (59.73753072787354, 59.76264755924401);
- parameters approximately 0.449122668574 and 0.500132696223;
- evaluating the library's arcs at those parameters gives positions only
  2.13e-14 apart.

Nevertheless `intersections.segment_with` returns `Ok([])` at tolerances from
5e-7 down to 1e-12. The default query fails on Erlang too. JavaScript fails in
both operand orders at depths 48 and 96. Restricting the quarter-circle to its
parameter interval [0.49,0.51] recovers the crossing. This identifies a concrete
numerical search miss sensitive to the relative parameter ranges; it is not
an endpoint reconciliation artifact. The general solver documents a bounded,
non-exhaustive search, but this is still a reproducible missed crossing to fix,
not a passing parity comparison.

At CSG tolerance 1e-6 the result has four arcs and the observed discrepancy.
At 1e-7 or smaller it has five arcs with sampled boundary discrepancy below
1.75e-11. Changing minimum length alone does not help. A tighter CSG tolerance
changes its refinement path; it does not fix the standalone full-arc query.

Evidence and runnable investigations:

- `probe-continuity-4295.mjs` / `remaining-continuity-4295.json`: tolerance/minimum sweeps.
- `certify-continuity-4295.py` / `remaining-continuity-4295-analytic.json`: independent circle certificate.
- `probe-continuity-4295-witness.mjs` / `remaining-continuity-4295-witness.json`: evaluated witness, order/depth checks, cropped-arc recovery.

No production fix, full-suite rerun, or figure regeneration was performed for
this audit-only work. FL006 remains open. The other general assertion/adaptation
gaps in `COVERAGE-GAPS.md` remain separate; completing these twelve comparisons
does not complete all upstream assertion coverage.
