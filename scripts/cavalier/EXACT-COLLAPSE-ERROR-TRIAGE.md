# Exact circular-offset collapse — 2026-10-20

Disposition: existing native degeneracy limitation / different API expectations,
not a newly confirmed numerical bug. Covers all six error records in the
402-case offset replay: CC01309–CC01312, CC01475 and CC01479.

The four circle cases collapse radius-one arcs with an inward offset of one.
The two `test_specific::case6` records are opposite traversals of the same open
path (with opposite offset signs), not different self-intersection options.
Their fourth segment is a radius-45 semicircle from (230,0) to (320,0), reversed
in CC01479. Its inward offset is exactly 45. The offset circle has radius zero.

JavaScript segment-by-segment replay identifies this segment as the only failure
in each seven-segment path. Both complete paths fail with `DegenerateTangent(0)`
with default trimming and with all trimming disabled. The four circle records
fail on both component semicircles. This is construction-stage rejection, not
arrangement classification or trimming loss.

The isolated radius-45 arc rejects exactly 45 in both orientations on JavaScript
and Erlang. Inward offsets 44.999 and 45.001 succeed on both targets. The complete
two case6 inputs also reproduce the error on Erlang. Across-center success is
consistent with signed normal extrusion, not filled-region erosion.

This agrees with the explicit existing native regression
`svg_path_offset_test.gleam: segment_rejects_collapsed_circular_arc_offset_test`
and the `circular_arc_offset_radius` guard in `offset_e_join_free_segment_attempt`.
Cavalier instead returns an empty result for the collapsed circle and a surviving
open walk for case6. Supporting that result requires a deliberate rule for
removing collapsed pieces and reconnecting their neighbours. It is a possible
future offset policy improvement, not a reason to weaken the current error guard.
No production behavior or public API changed here.

## Reproduction

- `node scripts/cavalier/probe-exact-collapse-errors.mjs`
  (existing portable JavaScript build): six full inputs, default/untrimmed
  results, every source segment, and six isolated nearby-distance controls.
  Captured in `exact-collapse-errors.json`.
- In `scripts/cavalier/probe`: `gleam run -m exact_collapse_audit_probe`:
  six isolated controls and both full case6 inputs; all expected outcomes
  reproduced. Captured in `exact-collapse-erlang.log`.

These are diagnostic probes, not additions to the counted test suite. No full
suite or figure rerun was needed for this documentation-only investigation.

## Reopened after review

The conclusion above is superseded by `COLLAPSED-STALLED-RUN-REPAIR.md`.
The stalled-run mechanism can represent the collapsed run while retaining its
source tangents for both joins. Treating all six errors as settled API policy
was premature; the existing rejection test described the old behavior, not a
sufficient reason to retain it.
