# Item_Bounds.js

[Audit index](../INDEX.md) · [Archive](../upstream/Item_Bounds.js)

Original path: `test/tests/Item_Bounds.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `32ff615bef8e8a25afd8d5483de77b5b3ee578249bddf20ecae338a74e5b5ad3`.
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

- [paper_bounds_probe.gleam](../../../test_paperjs/src/paper_bounds_probe.gleam)

## Raw comparison drivers (not release tests)

None.

## Evidence and extracted fixtures

- [bounds-status.json](../bounds-status.json)
- [first-stroke-bounds-findings.json](../first-stroke-bounds-findings.json)
- [remaining-stroke-bounds-findings.json](../remaining-stroke-bounds-findings.json)
- [bounds.json](../bounds.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'item.bounds caching'` — scene-api-not-adapted
- Block 1: `'group.bounds when group contains empty group'` — scene-api-not-adapted
- Block 2: `'group.bounds and position after children were modified'` — scene-api-not-adapted
- Block 3: `'group.bounds when containing empty path first'` — scene-api-not-adapted
- Block 4: `'path.bounds when contained in a transformed group'` — scene-api-not-adapted
- Block 5: `'shape.strokeBounds when scaled without strokeScaling'` — scene-api-not-adapted
- Block 6: `'text.bounds'` — scene-api-not-adapted
- Block 7: `'path.bounds'` — extracted-geometry-subset
- Block 8: `'path.strokeBounds on path without stroke'` — extracted-geometry-subset
- Block 9: `'path.strokeBounds on path with single segment and stroke color'` — extracted-geometry-subset
- Block 10: `'path.strokeBounds on closed path with single segment and stroke color'` — extracted-geometry-subset
- Block 11: `'path.strokeBounds with corners and miter limit'` — extracted-geometry-subset
- Block 12: `'path.bounds & path.strokeBounds with stroke styles'` — extracted-geometry-subset
- Block 13: `'path.strokeBounds with rectangles'` — extracted-geometry-subset
- Block 14: `'path.strokeBounds without strokeScaling and zoomed view'` — extracted-geometry-subset
- Block 15: `'shape.strokeBounds without strokeScaling and zoomed view'` — scene-api-not-adapted
- Block 16: `'path.bounds'` — extracted-geometry-subset
- Block 17: `'path.strokeBounds on path without stroke'` — extracted-geometry-subset
- Block 18: `'path.strokeBounds on path with single segment and stroke color'` — extracted-geometry-subset
- Block 19: `'path.strokeBounds on closed path with single segment and stroke color'` — extracted-geometry-subset
- Block 20: `'path.strokeBounds with corners and miter limit'` — extracted-geometry-subset
- Block 21: `'path.bounds & path.strokeBounds with stroke styles'` — extracted-geometry-subset
- Block 22: `'path.strokeBounds with rectangles'` — extracted-geometry-subset
- Block 23: `'path.strokeBounds without strokeScaling and zoomed view'` — scene-api-not-adapted
- Block 24: `'shape.strokeBounds without strokeScaling and zoomed view'` — scene-api-not-adapted
- Block 25: `'path.internalBounds'` — extracted-geometry-subset
- Block 26: `'compoundPath.strokeBounds'` — extracted-geometry-subset
- Block 27: `'path.strokeBounds with applyMatrix disabled'` — extracted-geometry-subset
- Block 28: `'path.strokeBounds with applyMatrix enabled'` — extracted-geometry-subset
- Block 29: `'symbolItem.bounds with strokeScaling disabled'` — scene-api-not-adapted
- Block 30: `'item.visible and item.parents.bounds (#1248)'` — scene-api-not-adapted
- Block 31: `'group.internalBounds with child and child.applyMatrix = false (#1250)'` — scene-api-not-adapted
- Block 32: `'item._globalMatrix on item after empty symbol (#1561)'` — scene-api-not-adapted
- Block 33: `'path.strokeBounds of open, circular arc (#1817)'` — extracted-geometry-subset
- Block 34: `'path.strokeBounds applies stroke padding properly (#1824)'` — extracted-geometry-subset
