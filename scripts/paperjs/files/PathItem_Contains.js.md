# PathItem_Contains.js

[Audit index](../INDEX.md) · [Archive](../upstream/PathItem_Contains.js)

Original path: `test/tests/PathItem_Contains.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `3345f42240b4d75855b527b366f4d109c9dbe9fc636f5f5b4eb0444e74262996`.
Download date: not recorded. Archive consolidated: 2026-10-14.

## Scope

Detailed core inventory; see inventory.json and linked reports.

prior detailed audit plus final dispositions.

This file-level disposition is not a claim that every assertion was executed or passed.

## Fast release adaptations

[svg_path_paper_containment_test.gleam](../../../test/svg_path_paper_containment_test.gleam)

- `paper_containment_block_0_test`
- `paper_containment_block_1_test`
- `paper_containment_block_2_test`
- `paper_containment_block_3_test`
- `paper_containment_block_4_test`
- `paper_containment_block_5_test`
- `paper_containment_block_7_test`
- `paper_containment_block_8_test`
- `paper_containment_block_9_test`
- `paper_containment_block_10_test`
- `paper_containment_block_11_test`
- `paper_containment_block_12_test`
- `paper_containment_block_13_test`

## Slow release adaptations

None.

## Shared adaptation helpers

None.

## Native regressions with related provenance

None.

## Diagnostic probes (not release tests)

None.

## Raw comparison drivers (not release tests)

None.

## Evidence and extracted fixtures

- [containment-screening.json](../containment-screening.json)
- [containment.json](../containment.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'Path#contains() (regular polygon: #208)'` — extracted
- Block 1: `'Path#contains() (circle contours)'` — extracted
- Block 2: `'Path#contains() (transformed circle contours)'` — extracted
- Block 3: `'Path#contains() (round rectangle: #227)'` — extracted
- Block 4: `'Path#contains() (open circle)'` — extracted
- Block 5: `'CompoundPath#contains() (donut)'` — extracted
- Block 6: `'Shape#contains()'` — adapted-exact-shape-containment-match
- Block 7: `'Path#contains() (rectangle contours)'` — extracted
- Block 8: `'Path#contains() (rotated rectangle contours)'` — extracted
- Block 9: `'Path#contains() (touching stationary point with changing orientation)'` — extracted
- Block 10: `'Path#contains() (complex shape: #400)'` — extracted
- Block 11: `'Path#contains() (straight curves with zero-winding: #943)'` — extracted
- Block 12: `'CompoundPath#contains() (nested touching circles and other edge cases: #944)'` — extracted
- Block 13: `'Path#contains() with Path#interiorPoint: #854, #1064'` — extracted
- Block 14: `'IPathtem#contains() with non-invertible matrices (#1651)'` — scene-matrix-api-difference-empty-geometry-checked
