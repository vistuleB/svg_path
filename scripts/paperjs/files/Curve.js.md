# Curve.js

[Audit index](../INDEX.md) · [Archive](../upstream/Curve.js)

Original path: `test/tests/Curve.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `65e23806d1864f7f6a3aa67adefa66148353c5359949c2bbaef61f0a242676a4`.
Download date: not recorded. Archive consolidated: 2026-10-14.

## Scope

Detailed core inventory; see inventory.json and linked reports.

prior detailed audit plus final dispositions.

This file-level disposition is not a claim that every assertion was executed or passed.

## Fast release adaptations

[svg_path_paper_curves_test.gleam](../../../test/svg_path_paper_curves_test.gleam)

- `paper_curve_0_test`
- `paper_curve_1_test`
- `paper_curve_2_test`
- `paper_curve_3_test`
- `paper_curve_4_test`
- `paper_curve_5_test`
- `paper_curve_6_test`
- `paper_curve_7_test`
- `paper_curve_8_test`
- `paper_curve_9_test`
- `paper_curve_10_test`
- `paper_curve_11_test`
- `paper_curve_12_test`
- `paper_curve_13_test`
- `paper_curve_14_test`
- `paper_curve_15_test`
- `paper_curve_16_test`
- `paper_curve_17_test`
- `paper_curve_18_test`
- `paper_curve_19_test`
- `paper_curve_20_test`
- `paper_curve_21_test`
- `paper_curve_22_test`
- `paper_curve_23_test`
- `paper_curve_24_test`
- `paper_curve_25_test`
- `paper_curve_26_test`
- `paper_curve_27_test`
- `paper_curve_28_test`
- `paper_curve_29_test`
- `paper_curve_30_test`
- `paper_curve_31_test`
- `paper_curve_32_test`
- `paper_curve_33_test`
- `paper_curve_34_test`
- `paper_curve_35_test`
- `paper_curve_36_test`
- `paper_curve_37_test`
- `paper_curve_38_test`
- `paper_curve_39_test`
- `paper_curve_40_test`
- `paper_curve_41_test`
- `paper_curve_42_test`
- `paper_curve_43_test`
- `paper_curve_44_test`

[svg_path_paper_curve_remaining_test.gleam](../../../test/svg_path_paper_curve_remaining_test.gleam)

- `paper_curve_inverse_length_round_trips_test`
- `paper_curve_length_distance_contract_test`
- `paper_curve_location_out_of_range_test`
- `paper_curve_time_of_rectangle_points_test`
- `paper_curve_division_0_test`
- `paper_curve_division_1_test`
- `paper_curve_tangent_roots_1_test`
- `paper_curve_tangent_roots_2_test`
- `paper_curve_tangent_roots_3_test`
- `paper_curve_tangent_roots_4_test`
- `paper_curve_tangent_roots_5_test`
- `paper_curve_tangent_roots_6_test`
- `paper_curve_tangent_roots_7_test`

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

- [curve-status.json](../curve-status.json)
- [curve-remaining-status.json](../curve-remaining-status.json)
- [curves.json](../curves.json)
- [curve-remaining.json](../curve-remaining.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'Curve#classify()'` — no-direct-public-counterpart
- Block 1: `'Curve#getPointAtTime()'` — extracted-subset
- Block 2: `'Curve#getTangentAtTime()'` — extracted-subset
- Block 3: `'Curve#getNormalAtTime()'` — extracted-subset
- Block 4: `'Curve#getCurvatureAtTime()'` — extracted-subset
- Block 5: `'Curve#getCurvatureAtTime()'` — extracted-subset
- Block 6: `'Curve#getTimeAt()'` — adapted-geometry-checks
- Block 7: `'Curve#getTimeAt() with straight curve'` — extracted-subset
- Block 8: `'Curve#getTimeAt() with straight curve'` — extracted-subset
- Block 9: `'Curve#getTimeAt() with offset at end of curve'` — extracted-subset
- Block 10: `'Curve#getLocationAt()'` — adapted-geometry-checks
- Block 11: `'Curve#isStraight()'` — no-direct-public-counterpart
- Block 12: `'Curve#isLinear()'` — no-direct-public-counterpart
- Block 13: `'Curve#getTimeOf()'` — adapted-geometry-checks
- Block 14: `'Curve#getPartLength() with straight curve'` — extracted-subset
- Block 15: `'Curve#divideAt(offset)'` — adapted-geometry-checks
- Block 16: `'Curve#getTimesWithTangent()'` — adapted-geometry-checks
