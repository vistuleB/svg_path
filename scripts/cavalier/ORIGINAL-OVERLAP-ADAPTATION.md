# Original continuous-overlap comparisons — 2026-10-20

Native revision `09d30a1`, Gleam JavaScript. No production edits.
Pinned upstream: `22887a824d22cd8ab50968a551f34cdb4508127f`, version 0.9.0.

The original point-only adapter deferred all 53 captured `Overlapping*` results:
38 polyline-segment pairs, 14 line-line pairs, and one coincident-circle pair.
This pass adapts these to `encounters.segment_with`. It does not overwrite the
baseline results. The other two of the original 55 contract-difference records
concern boundary winding, not continuous overlap.

## Checks

- Segment pairs: compare the unordered interval endpoints at absolute 1e-6.
  Line-line upstream parameters belong to the second segment and are converted
  to geometric endpoints on that segment. Reversed traversal is retained in
  native parameter intervals; output ordering is not required to match upstream.
- Circles: represent each circle by two semicircles. Require two full overlap
  intervals covering the two left semicircles and corresponding right spans.
  Shared semicircle endpoints are not additional continuous intervals.
- Sample each affine overlap correspondence at 17 equally spaced fractions,
  including endpoints, and compare left/right positions to the requested native
  overlap tolerance. These are numerical checks, not a proof over all parameters.

`node scripts/cavalier/probe-original-overlaps.mjs`:
52 matches, one explicit certification error, no timeout. The maximum sampled
residual among the 52 matches is 1.6011864169946886e-15.

## CC01771: different accuracy settings at large coordinates

`overlapping_arcs_handle_angle_wrap_at_different_scales`, scale 1e9, has
coordinates around 3e9 and upstream `pos_equal_eps = 10000`. Our default 1e-9
request fails certification with distance 4.76837158203125e-7: one coordinate
ULP at this magnitude. This is an explicit refusal, not a silent incorrect
interval. It is not an equal-settings comparison or a demonstrated contract bug.

Two explicit-options controls return the expected interval:

- Native tolerance 1e-5: endpoint check passes, sampled residual 6.743495761743046e-7.
- Native tolerance 10000 (upstream's positional value): same interval/residual.

The controls are separate records; the failed default result remains visible.
No global tolerance policy change is proposed in this batch.

## Records and reproduction

- `original-overlap-results.jsonl`: all 53 default observations.
- `original-overlap-large-coordinate-control.jsonl`: tolerance 1e-5 control.
- `original-overlap-upstream-tolerance-control.jsonl`: tolerance 10000 control.

```sh
node scripts/cavalier/probe-original-overlaps.mjs
AUDIT_CASE_ID=CC01771 AUDIT_OVERLAP_TOLERANCE=0.00001 node scripts/cavalier/probe-original-overlaps.mjs
AUDIT_CASE_ID=CC01771 AUDIT_OVERLAP_TOLERANCE=10000 node scripts/cavalier/probe-original-overlaps.mjs
```

This closes the original selected overlap-adaptation gap, with the settings
mismatch explicitly recorded. It does not adapt all upstream overlap-list
ordering, slice-provenance, or routing assertions. F# and Erlang are not replayed
in this diagnostic batch; no full-suite rerun or commit was performed.
