# Path_Constructors.js

[Audit index](../INDEX.md) · [Archive](../upstream/Path_Constructors.js)

Original path: `test/tests/Path_Constructors.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `da3782f4cafb8813d17612eb2211a78ecd11d252e07c4ce2b23972944114e186`.
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

- [paper_constructors_probe.gleam](../../../test_paperjs/src/paper_constructors_probe.gleam)

## Raw comparison drivers (not release tests)

None.

## Evidence and extracted fixtures

- [constructors-status.json](../constructors-status.json)
- [constructors.json](../constructors.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'new Path.Rectangle([50, 50], [100, 100])'` — adapted-constructor-match
- Block 1: `'new Path.Rectangle({ from: [50, 50], to: [150, 150] })'` — adapted-constructor-match
- Block 2: `'new Path.Circle([100, 100], 50)'` — adapted-constructor-match
- Block 3: `'new Path.Circle({ center: [100, 100], radius: 50 })'` — adapted-constructor-match
- Block 4: `'new Path.Circle({ center: [100, 100], radius: 50, insert: true })'` — scene-api-not-adapted
- Block 5: `'new Path.Ellipse(rect)'` — adapted-constructor-match
- Block 6: `'new Path.Rectangle(rectangle, radius)'` — adapted-constructor-match
- Block 7: `'new Path.Rectangle({ rectangle: rectangle, radius: radius })'` — adapted-constructor-match
- Block 8: `'new Path.Rectangle(rect, size) - too large size'` — adapted-constructor-match
- Block 9: `'new Path.Arc(from, through, to)'` — no-direct-constructor-counterpart
- Block 10: `'new Path.Arc({ from: from, through: through, to: to })'` — no-direct-constructor-counterpart
- Block 11: `'new Path.RegularPolygon(center, sides, radius)'` — no-direct-constructor-counterpart
- Block 12: `'new Path.RegularPolygon({ center: center, sides: sides, radius: radius })'` — no-direct-constructor-counterpart
- Block 13: `'new Path.Star(center, points, radius1, radius2)'` — no-direct-constructor-counterpart
- Block 14: `'new Path.Star({ center: center, points: points, radius1: radius1, radius2: radius2 })'` — no-direct-constructor-counterpart
- Block 15: `'new Path.Line(from, to)'` — adapted-constructor-match
- Block 16: `'new Path.Line({ from: from, to: to })'` — adapted-constructor-match
- Block 17: `'new Path.Line({ insert: false })'` — scene-api-not-adapted
