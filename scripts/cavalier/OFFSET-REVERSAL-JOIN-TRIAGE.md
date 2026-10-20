# Offset reversal join investigation — 2026-10-20

Follow-up: the candidate is now implemented and fully validated; see
`OFFSET-REVERSAL-JOIN-REPAIR.md`. The investigation below records the pre-fix state.

Baseline `6da0b70`. Confirmed native failure, reduced and reproduced on JavaScript
and Erlang. Production source is unchanged; no fix has been tried in this batch.

## Original discrepancy: CC01192 / CC01196

`closed_pline1` at inward distance 26 returns empty under default trimming at
fitting tolerances 0.01, 0.001 and 0.0001. Both captured IDs have identical input
and distance; their upstream self-intersection handling option differs.

Stage isolation on CC01192:

| Trimming | Result |
| --- | --- |
| None | One raw contour, area 27824.472271721264 |
| Offside only | One small contour, area -0.7550642016467322 |
| In-band only | One contour, area 29004.22543405943 |
| Default (both) | Empty |

The in-band-only contour matches upstream perimeter 879.9419421394236 and bounds,
but upstream area is 26880.508800232714. Full upstream curve capture isolates the
difference: the join from (199,0) to (251,0), centered at (225,0), has radius 26.
Cavalier traverses the upper semicircle (positive y); native construction traverses
the lower semicircle (negative y), split into three pieces after arrangement.
The area difference is exactly pi*26^2 to numerical precision. Bounds and perimeter
alone concealed this substantial difference in geometry.

Observational tracing shows the offside flood itself classifies the sampled edge
midpoints correctly: 25 retained edges are inside the normalized source, 11
rejected edges outside. Source self-intersection query returns no hits. The
outward join breaks the larger surviving closed walk, leaving only the small loop,
which the final in-band stage removes. Do not attribute this to fitting tolerance
or a generic failure of dual face classification.

## Native reduction

Use two radius-1 positive-sweep semicircles:

- (-2,0) to (0,0), center (-1,0).
- (0,0) to (2,0), center (1,0).

Close with straight lines (2,0) -> (2,2) -> (-2,2) -> (-2,0).
At native signed offset -0.25, Round join, Butt cap, defaults:

- Forward traversal returns `Ok([])`.
- Reverse traversal with offset +0.25 returns one contour (signed area
  -7.793971097219577).

All four quarter-turn rotations reproduce this discrepancy in JavaScript.
The direct Gleam/Erlang probe reproduces both default results. This establishes
a native reversal inconsistency without depending on Cavalier or bulge conversion.

The raw forward join runs (-0.25,0) -> (0.25,0), radius 0.25, positive sweep.
Its midpoint (0,-0.25) is outside the source. The alternative semicircle midpoint
(0,+0.25) is inside. Reversing the source and offset preserves the intended physical
side, yet changes which semicircle is chosen and whether any final offset survives.

## Diagnosis and proposed repair scope

`round_join` computes `signed_angle(start_radius,end_radius)` and chooses sweep
from `angle > 0`. For antiparallel radii the angle is +180 in both traversal
directions, so the same sweep is selected instead of reversing it. The routine
uses the offset only for the radius, losing the signed-side information at the tie.

Candidate: resolve the exact/near-antiparallel tie using the signed offset and
appropriate source-side convention. In this reduction the needed sweep is
`offset > 0`. Preserve the endpoint-based center choice added for stalled curves;
do not revert wholesale to healed tangent angles. The correct numerical threshold
and behavior near, but not exactly at, 180 degrees still need testing. No candidate
implementation or full-suite success is claimed.

A repair should test reversal, quarter-turn rotations, both offset signs,
near-reversal perturbations, and the original fixture. Full offset/stroke tests
and published figures are warranted before adoption because Round joins are shared
by many paths. F# remains deferred until the Gleam audit is complete.

## Evidence

- `offset-closed-pline1-detail.json`, `*-none.json`, `*-offside.json`, `*-inband.json`.
- `prepare-closed-pline1-trace.py`, generated `probe-closed-pline1-trace.mjs`,
  `offset-closed-pline1-trace.json`: copied-build observation, unchanged returns.
- `check-closed-pline1-faces.mjs`, `offset-closed-pline1-face-check.json`.
- `probe-closed-pline1-source.mjs`, `offset-closed-pline1-source.json`.
- `offset-closed-pline1-upstream.json`: actual upstream curves, captured with
  the existing full-geometry instrumentation. Pinned `closed_pline1` Rust test
  passed; see `offset-closed-pline1-upstream-test.log`.
- `offset-reversal-fixture.json`, `offset-reversal-variants.json`,
  `offset-reversal-default.json`, `offset-reversal-none.json`, and
  `offset-reversal-variant-results.json`.
- `probe/src/offset_reversal_audit_probe.gleam`, `offset-reversal-erlang.log`.

Run `probe-offset-detail.mjs` with AUDIT_CASE_ID, optional AUDIT_CASE_FILE,
AUDIT_TOLERANCE and AUDIT_TRIMMING (`default`, `none`, `offside-only`, `no-offside`).
The native Erlang reduction runs with `gleam run -m offset_reversal_audit_probe`
from `scripts/cavalier/probe`. Diagnostics only; no full suite or figures rerun.
