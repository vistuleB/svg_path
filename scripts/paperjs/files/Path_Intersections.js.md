# Path_Intersections.js

[Audit index](../INDEX.md) · [Archive](../upstream/Path_Intersections.js)

Original path: `test/tests/Path_Intersections.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `4c5ca23d22e5f44970da9cecde43a36deaeb026875477c60fbe28d46d71fc675`.
Download date: not recorded. Archive consolidated: 2026-10-14.

## Scope

Detailed core inventory; see inventory.json and linked reports.

prior detailed audit plus final dispositions.

This file-level disposition is not a claim that every assertion was executed or passed.

## Fast release adaptations

[svg_path_paper_intersections_test.gleam](../../../test/svg_path_paper_intersections_test.gleam)

- `paper_00_test`
- `paper_01_test`
- `paper_02_test`
- `paper_03_test`
- `paper_04_test`
- `paper_05_test`
- `paper_06_test`
- `paper_07_test`
- `paper_08_test`
- `paper_09_test`
- `paper_10_test`
- `paper_11_test`
- `paper_14_test`
- `paper_15_test`
- `paper_16_test`
- `paper_17_test`
- `paper_20_test`
- `paper_21_test`
- `paper_22_test`
- `paper_25_test`
- `paper_26_test`

[svg_path_paper_intersection_addresses_test.gleam](../../../test/svg_path_paper_intersection_addresses_test.gleam)

- `paper_address_00_test`
- `paper_address_01_test`
- `paper_address_02_test`
- `paper_address_03_test`
- `paper_address_04_test`
- `paper_address_05_test`
- `paper_address_06_test`
- `paper_address_07_test`
- `paper_address_08_test`
- `paper_address_09_test`
- `paper_address_10_test`
- `paper_address_11_test`
- `paper_address_13_test`
- `paper_address_14_test`
- `paper_address_15_test`
- `paper_address_16_test`
- `paper_address_17_test`
- `paper_address_18_test`
- `paper_address_20_test`
- `paper_address_21_test`
- `paper_address_22_test`
- `paper_address_23_test`
- `paper_address_24_test`
- `paper_address_25_test`
- `paper_address_26_test`
- `paper_address_27_test`
- `paper_address_31_test`

[svg_path_paper_crossings_1409_test.gleam](../../../test/svg_path_paper_crossings_1409_test.gleam)

- `paper_1409_assertion_1_test`
- `crossing_adapter_retains_transverse_crossings_test`

## Slow release adaptations

[svg_path_paper_intersection_addresses_slow_test.gleam](../../../test_slow/svg_path_paper_intersection_addresses_slow_test.gleam)

- `paper_address_12_test`
- `paper_address_19_test`

[svg_path_paper_crossings_1409_slow_test.gleam](../../../test_slow/svg_path_paper_crossings_1409_slow_test.gleam)

- `paper_1409_assertion_2_test`
- `paper_1409_assertion_3_test`

## Shared adaptation helpers

- [svg_path_paper_intersection_support.gleam](../../../test/svg_path_paper_intersection_support.gleam)

## Native regressions with related provenance

None.

## Diagnostic probes (not release tests)

None.

## Raw comparison drivers (not release tests)

- [audit_tests.gleam](../../../scripts/paperjs/audit_tests.gleam)
- [probe-intersections.mjs](../../../scripts/paperjs/probe-intersections.mjs)
- [probe-intersection-addresses.mjs](../../../scripts/paperjs/probe-intersection-addresses.mjs)

## Evidence and extracted fixtures

- [intersection-status.json](../intersection-status.json)
- [INTERSECTION_ADDRESSES.md](../INTERSECTION_ADDRESSES.md)
- [CROSSINGS_1409.md](../CROSSINGS_1409.md)
- [intersections.json](../intersections.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'#565'` — extracted-address-and-classification-audit
- Block 1: `'#568'` — extracted-address-and-classification-audit
- Block 2: `'#570'` — extracted-address-and-classification-audit
- Block 3: `'#571'` — extracted-address-and-classification-audit
- Block 4: `'overlapping circles'` — extracted-address-and-classification-audit
- Block 5: `'circle and square (existing segments overlaps on curves)'` — extracted-address-and-classification-audit
- Block 6: `'intersecting paths with applyMatrix = true / false'` — extracted-address-and-classification-audit
- Block 7: `'#904'` — extracted-address-and-classification-audit
- Block 8: `'#1066'` — extracted-address-and-classification-audit
- Block 9: `'#1073#issuecomment-234305530'` — extracted-address-and-classification-audit
- Block 10: `'#1074'` — extracted-address-and-classification-audit
- Block 11: `'#1088'` — extracted-address-and-classification-audit
- Block 12: `'#1165'` — extracted-address-and-classification-audit
- Block 13: `'#1174'` — extracted-address-and-classification-audit
- Block 14: `'#1197'` — extracted-address-and-classification-audit
- Block 15: `'#1233'` — extracted-address-and-classification-audit
- Block 16: `'#1239'` — extracted-address-and-classification-audit
- Block 17: `'#1270'` — extracted-address-and-classification-audit
- Block 18: `'#1284'` — extracted-address-and-classification-audit
- Block 19: `'#1638'` — extracted-address-and-classification-audit
- Block 20: `'#1263'` — extracted-address-and-classification-audit
- Block 21: `'#1262'` — extracted-address-and-classification-audit
- Block 22: `'#1409'` — adapted-crossing-checks
- Block 23: `'#1255'` — extracted-address-and-classification-audit
