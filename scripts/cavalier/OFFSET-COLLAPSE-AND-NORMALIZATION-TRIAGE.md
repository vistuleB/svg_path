# Offset collapse and source normalization — 2026-10-19

Source `e936c7b`. The native cleanup repair is now in the working tree; F# remains deferred.

## Collapse discrepancies: construction and policy distinction

`probe-offset-collapse.mjs` replays a unit circle and square with inward distances
0.5, 1, 1.5, 2, 2.5, 3 under four trimming combinations (48 cases).
`offset-collapse-triage.json` retains output areas and serialized walks.

For the circle (center (1,0), radius 1), default output is:

| Inward distance | Result |
| --- | --- |
| 0.5 | Radius 0.5 |
| 1 | `DegenerateTangent(0)` |
| 1.5 | Radius 0.5 |
| 2 | Radius 1 |
| 2.5 or 3 | Empty |

The native Erlang probe reproduces this default sequence, recorded in
`offset-collapse-erlang.log`. With offside trimming disabled, distances 2.5 and 3
instead yield radii 1.5 and 2. The beyond-center circle is constructed from the
normal extrusion: signed radius 1-d becomes negative, endpoints move through the
center, and the stored arc uses its absolute radius. This is explicitly exercised
by `segment_offsets_circular_arc_across_center_test`. Exact collapse rejection is
also explicitly tested by `segment_rejects_collapsed_circular_arc_offset_test`.

Offside trimming rejects the beyond-center circle once it lies outside the source,
but retains it while it is inside or coincident. In-band trimming does not remove
it in these cases. Thus this pipeline is not equivalent to filled-region erosion,
which would remain empty after d=1. No such general erosion guarantee was found
in the offset docs. The low-level across-center behavior is intentional; whether
high-level trimming should discard it is still a policy question, not a confirmed
contract bug. Do not generalize this explanation into proof that all square output
is correct: the square's extra contours remain a trimming-policy investigation.

## Confirmed bug: cleanup deletes a distinct endpoint

Original representatives CC01160 and CC01292 fail with a gap equal to the chord
of a short intermediate arc. Isolating that arc shows the same cause as this
native reduction (no bulge conversion needed):

- radius-1 circular arc from (0,0) to (0.00003,0), small arc, positive sweep;
- cleanup tolerance 0.001.

`degeneracy.normalize_degenerate_segments` returns an empty subpath at (0,0),
losing the distinct endpoint (0.00003,0). The public function promises each
selected window preserves its start and end. This is a direct contract violation.

Place this arc between lines (-1,0) → (0,0) and (0.00003,0) → (0.00003,1).
The input is exactly continuous. `offset.normalize_short_source_runs` deletes
its middle arc, and strict reconstruction fails with `Discontinuous`, distance
3e-5. Public `offset.subpath` returns that error too.

Both Erlang and JS reproduce this. JS also checks radii 10 and 100 and the exact
short-arc coordinates from CC01160/CC01292, all with the same mechanism.

### Code path and candidate repair

The initial diagnosis named `point_traversal_lines`, but review before the repair
showed that its caller already passes zero tolerance. That was not the failing
path. A singleton arc instead goes through `segment_degenerate_lines_valid` and
then `degenerate_line_list`. When all flattened points lie within tolerance,
`degenerate_line_axis` returns None; the old None branch returned `Some([])`.
It incorrectly equated lack of a sufficiently long axis with no movement.

The repair preserves the already-linearized connections in that branch and
removes only exact zero-length lines. It does not change endpoint reconciliation,
source tolerances or geometry in other stages. Three permanent regressions in
`test/svg_path_short_arc_cleanup_test.gleam` cover standalone cleanup and endpoint
preservation, offset continuity in both orientations, and short versus exact-zero
line traversal. They are selected for portable testing.

`probe-short-arc-repaired.mjs` replays all four original discontinuity cases:
CC01160, CC01189, CC01292 and CC01296. All four now normalize and construct offsets
successfully. `short-arc-repaired-originals.json` also records output properties:

- CC01296 matches the audit's 1e-4 aggregate-property threshold.
- CC01160 and CC01292 still differ in length/bounds (and area for CC01160).
- CC01189 returns one contour where the upstream fixture expects none.

Thus this repairs the native endpoint-loss failure, not every discrepancy in
those fixtures. The remaining property/trimming differences require separate
classification; no geometry-equivalence claim is made.

### Evidence

- `probe-short-arc-normalization.mjs`, `short-arc-normalization.json`.
- `probe/src/short_arc_normalization_audit_probe.gleam`,
  `short-arc-normalization-erlang.log`.
- `probe/src/offset_collapse_audit_probe.gleam`, `offset-collapse-erlang.log`.

The initial diagnostic investigation did not run full suites. The subsequent
repair validation is recorded below.

## Completed repair validation

`PATH=/Users/jpsteinb/.nvm/versions/node/v24.10.0/bin:$PATH scripts/test-release`
completed successfully, exit 0:

- 2,057 ordinary tests passed.
- 31 slow tests passed.
- 803 portable tests passed on Erlang.
- 803 portable tests passed on JavaScript.

All three new regressions are included. Raw log:
`short-arc-cleanup-test-release.log`. Formatting, README recipe consistency,
audit-record validation and diff whitespace checks passed. The fix remains
uncommitted. Figures were not regenerated; F# remains deferred.
