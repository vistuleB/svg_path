# FL006 arc-overlap fix and validation

The remaining FL006 bug is fixed in Gleam commit `efcc3aa`, after ranking-fix
commit `0a67c0a`. The arc guard is ported and validated in F# commit `7ee6a3a`.

## Implementation

Before sampled coincidence validation, arc/arc proposals now compare normalized
tangents at the two proposed interval midpoints, accounting for each interval's
parameter direction. Opposed mapped directions reject the overlap proposal.
Derivative evaluation errors propagate; normalization failure rejects the
proposal. Normalization avoids the temporary experiment's raw-product overflow
risk. This matches the existing line guard's direction requirement without
extending it to polynomial curves, whose traversal can have stationary points.

The rejected FL006 proposal lies entirely within the caller's geometric
tolerance near an endpoint, but pairs the arcs backwards. Previously that
proposal caused `OverlappingSegments`, which arrangement suppressed for a
shared endpoint, also suppressing a separate interior crossing. The guard
lets the ordinary crossing query proceed. No tolerances, CSG options, minimum
lengths, or arrangement policies change. The public overlap module now documents
the paired-direction requirement for lines and arcs.

## Regression coverage

`test/svg_path_flatten_arc_overlap_test.gleam` is included in the portable suite:

- Reduced arc pair rejects the backwards overlap and recovers the independently
  established crossing in all eight operand-order/traversal combinations.
- Valid partial arc overlaps survive operand reversal and reversed traversal;
  their returned parameter correspondence is checked on evaluated points.
- Original adapted CSG 4295 at default options retains a vertex at the crossing
  and the expected area. The test checks geometry rather than a segment-count
  snapshot. Fixture provenance and bounded endpoint reconciliation are recorded
  in the earlier continuity investigation.

## Completed validation

`scripts/test-release` passed **2,038 main + 31 slow + 784 portable Erlang +
784 portable JavaScript tests**. Full output: `remaining-fl006-overlap-release.log`.
Formatting, `git diff --check`, and `python3 scripts/flatten/catalog.py` passed.
No figures were regenerated in this change. The subsequent F# port passed
`scripts/test-release`: 2,018 main + 30 slow tests, including the three matching
regressions. See `remaining-fl006-fsharp-arc-release.log` and
[the completed F# port checklist](FSHARP-PORT-STATUS.md).

The original replay scripts were copied to `/tmp/fl006-production-replay` with
imports pointing to the newly compiled production runtime. Copies preserve the
historical output files. The twelve standalone comparisons ran under both
bounded reconciliation policies: **24 sampled matches, 5,980 boundary samples,
no query errors, maximum boundary distance 5.1176222368360824e-8**. Both operation
chains pass the existing area/membership comparisons. Chained 4296 now has seven
segments; segment count is diagnostic, not the sole comparison criterion.

Records identify the overlap source by SHA-256:

- `remaining-fl006-overlap-production-replay.json`
- `remaining-fl006-overlap-production-chains.json`
- `remaining-fl006-overlap-production-short.json`

The audit discrepancy is resolved in Gleam. This does not claim exhaustive
Flatten.js assertion parity or close the documented coverage gaps. F# ports
were subsequently completed in `c7a6e52`. Original failed observations and temporary experiments remain
available as historical evidence.
