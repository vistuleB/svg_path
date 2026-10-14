# Segment.js

[Audit index](../INDEX.md) · [Archive](../upstream/Segment.js)

Original path: `test/tests/Segment.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `2df05c4b258365d2c4a2875dc2b07ec4608196f0344a5309e8951a7ed59ab487`.
Download date: not recorded. Archive consolidated: 2026-10-14.

## Scope

Detailed core inventory; see inventory.json and linked reports.

prior detailed audit plus final dispositions.

This file-level disposition is not a claim that every assertion was executed or passed.

## Fast release adaptations

None.

## Slow release adaptations

None.

## Shared adaptation helpers

None.

## Native regressions with related provenance

None.

## Diagnostic probes (not release tests)

- [paper_segments_probe.gleam](../../../test_paperjs/src/paper_segments_probe.gleam)

## Raw comparison drivers (not release tests)

None.

## Evidence and extracted fixtures

- [segments-status.json](../segments-status.json)
- [segments.json](../segments.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'new Segment()'` — node-constructor-api-difference
- Block 1: `'new Segment(point)'` — node-constructor-api-difference
- Block 2: `'new Segment(x, y)'` — node-constructor-api-difference
- Block 3: `'new Segment(undefined)'` — node-constructor-api-difference
- Block 4: `'new Segment(object)'` — node-constructor-api-difference
- Block 5: `'new Segment(point, handleIn, handleOut)'` — node-constructor-api-difference
- Block 6: `'new Segment(null, null, null)'` — node-constructor-api-difference
- Block 7: `'new Segment(undefined, null, null)'` — node-constructor-api-difference
- Block 8: `'new Segment(x, y, inX, inY, outX, outY)'` — node-constructor-api-difference
- Block 9: `'new Segment(size)'` — node-constructor-api-difference
- Block 10: `'segment.reverse()'` — adapted-handle-reversal-match
- Block 11: `'segment.clone()'` — mutable-object-identity-api-difference
- Block 12: `'segment.remove()'` — node-editing-api-difference
- Block 13: `'segment.selected'` — scene-selection-api-difference
