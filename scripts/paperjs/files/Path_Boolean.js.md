# Path_Boolean.js

[Audit index](../INDEX.md) · [Archive](../upstream/Path_Boolean.js)

Original path: `test/tests/Path_Boolean.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `6462afa87758c863c92e3d184452f949524d09bce7083cae355b94ef3a32523a`.
Download date: not recorded. Archive consolidated: 2026-10-14.

## Scope

Detailed core inventory; see inventory.json and linked reports.

prior detailed audit plus final dispositions.

This file-level disposition is not a claim that every assertion was executed or passed.

## Fast release adaptations

[svg_path_paper_boolean_basics_test.gleam](../../../test/svg_path_paper_boolean_basics_test.gleam)

- `paper_boolean_00_test`
- `paper_boolean_01_test`
- `paper_boolean_02_test`
- `paper_boolean_03_test`
- `paper_boolean_04_test`
- `paper_boolean_05_test`
- `paper_boolean_06_test`
- `paper_boolean_07_test`
- `paper_boolean_08_test`
- `paper_boolean_09_test`
- `paper_boolean_10_test`
- `paper_boolean_11_test`
- `paper_boolean_12_test`
- `paper_boolean_13_test`
- `paper_boolean_14_test`
- `paper_boolean_15_test`

[svg_path_paper_boolean_recovered_test.gleam](../../../test/svg_path_paper_boolean_recovered_test.gleam)

- `paper_boolean_recovered_85_test`
- `paper_boolean_recovered_86_test`
- `paper_boolean_recovered_87_test`
- `paper_boolean_recovered_134_test`
- `paper_boolean_recovered_135_test`
- `paper_boolean_recovered_170_test`
- `paper_boolean_recovered_171_test`

[svg_path_paper_boolean_full_overlap_test.gleam](../../../test/svg_path_paper_boolean_full_overlap_test.gleam)

- `paper_boolean_full_overlap_122_test`
- `paper_boolean_full_overlap_123_test`

[svg_path_paper_boolean_adapters_test.gleam](../../../test/svg_path_paper_boolean_adapters_test.gleam)

- `paper_boolean_adapter_26_test`
- `paper_boolean_adapter_44_test`
- `paper_boolean_adapter_71_test`
- `paper_boolean_adapter_73_test`
- `paper_boolean_adapter_75_test`
- `paper_boolean_adapter_77_test`
- `paper_boolean_adapter_78_test`

[svg_path_paper_boolean_orientation_test.gleam](../../../test/svg_path_paper_boolean_orientation_test.gleam)

- `paper_boolean_973_equivalent_filled_region_test`

[svg_path_paper_boolean_tangent_test.gleam](../../../test/svg_path_paper_boolean_tangent_test.gleam)

- `paper_boolean_tangent_difference_172_test`

## Slow release adaptations

[svg_path_paper_boolean_full_overlap_slow_test.gleam](../../../test_slow/svg_path_paper_boolean_full_overlap_slow_test.gleam)

- `paper_boolean_full_overlap_107_test`

## Shared adaptation helpers

None.

## Native regressions with related provenance

- [svg_path_csg_cluster_join_test.gleam](../../../test/svg_path_csg_cluster_join_test.gleam)
- [svg_path_csg_face_winding_test.gleam](../../../test/svg_path_csg_face_winding_test.gleam)
- [svg_path_csg_tangent_order_test.gleam](../../../test/svg_path_csg_tangent_order_test.gleam)
- [svg_path_crossing_endpoint_test.gleam](../../../test/svg_path_crossing_endpoint_test.gleam)
- [svg_path_root_classification_regression_test.gleam](../../../test/svg_path_root_classification_regression_test.gleam)

## Diagnostic probes (not release tests)

- [paper_boolean_probe.gleam](../../../test_paperjs/src/paper_boolean_probe.gleam)
- [paper_final_boolean_probe.gleam](../../../test_paperjs/src/paper_final_boolean_probe.gleam)
- [paper_crossing_roots_probe.gleam](../../../test_paperjs/src/paper_crossing_roots_probe.gleam)
- [paper_crossing_probe.gleam](../../../test_paperjs/src/paper_crossing_probe.gleam)
- [paper_boolean_failures.gleam](../../../test_paperjs/src/paper_boolean_failures.gleam)
- [paper_boolean_remaining_probe.gleam](../../../test_paperjs/src/paper_boolean_remaining_probe.gleam)
- [paper_boundary_classification_regressions.gleam](../../../test_paperjs/src/paper_boundary_classification_regressions.gleam)
- [paper_new_overlap_probe.gleam](../../../test_paperjs/src/paper_new_overlap_probe.gleam)

## Raw comparison drivers (not release tests)

None.

## Evidence and extracted fixtures

- [BOOLEAN_AUDIT.md](../BOOLEAN_AUDIT.md)
- [BOOLEAN_ADAPTERS.md](../BOOLEAN_ADAPTERS.md)
- [BOOLEAN_ORIENTATION.md](../BOOLEAN_ORIENTATION.md)
- [FULL_OVERLAP_FIX.md](../FULL_OVERLAP_FIX.md)
- [FACE_WINDING_FIX.md](../FACE_WINDING_FIX.md)
- [BOOLEAN_TANGENT_FIX.md](../BOOLEAN_TANGENT_FIX.md)
- [CROSSING_BERNSTEIN_FIX.md](../CROSSING_BERNSTEIN_FIX.md)
- [booleans.json](../booleans.json)
- [boolean-adapter-fixtures.json](../boolean-adapter-fixtures.json)
- [boolean-orientation.json](../boolean-orientation.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'Boolean operations without crossings'` — baseline-geometry-screened
- Block 1: `'frame.intersect(rect)'` — baseline-geometry-screened
- Block 2: `'PathItem#resolveCrossings()'` — baseline-geometry-screened
- Block 3: `'#541'` — baseline-geometry-screened
- Block 4: `'#609'` — baseline-geometry-screened
- Block 5: `'#610'` — baseline-geometry-screened
- Block 6: `'#719'` — baseline-geometry-screened
- Block 7: `'#757 (path1.intersect(pat2, { trace: false }))'` — baseline-geometry-screened
- Block 8: `'#784'` — baseline-geometry-screened
- Block 9: `'#784#issuecomment-144653463'` — baseline-geometry-screened
- Block 10: `'#784#issuecomment-144993215'` — baseline-geometry-screened
- Block 11: `'#784#issuecomment-168605018'` — baseline-geometry-screened
- Block 12: `'#854'` — baseline-geometry-screened
- Block 13: `'#859'` — baseline-geometry-screened
- Block 14: `'#839'` — baseline-geometry-screened
- Block 15: `'#865'` — baseline-geometry-screened
- Block 16: `'#870'` — baseline-geometry-screened
- Block 17: `'#875'` — baseline-geometry-screened
- Block 18: `'#877'` — baseline-geometry-screened
- Block 19: `'#878'` — baseline-geometry-screened
- Block 20: `'#885'` — baseline-geometry-screened
- Block 21: `'#889'` — baseline-geometry-screened
- Block 22: `'#890'` — baseline-geometry-screened
- Block 23: `'#899'` — baseline-geometry-screened
- Block 24: `'#936'` — baseline-geometry-screened
- Block 25: `'#923'` — baseline-geometry-screened
- Block 26: `'#958'` — baseline-geometry-screened
- Block 27: `'#968'` — baseline-geometry-screened
- Block 28: `'#973'` — adapted-signed-contour-orientation-match
- Block 29: `'#1036'` — baseline-geometry-screened
- Block 30: `'#1054'` — baseline-geometry-screened
- Block 31: `'#1059'` — baseline-geometry-screened
- Block 32: `'#1075'` — baseline-geometry-screened
- Block 33: `'#1091'` — baseline-geometry-screened
- Block 34: `'#1109'` — baseline-geometry-screened
- Block 35: `'#1123'` — baseline-geometry-screened
- Block 36: `'#1123'` — baseline-geometry-screened
- Block 37: `'#1221'` — baseline-geometry-screened
- Block 38: `'#1239 / #1073'` — baseline-geometry-screened
- Block 39: `'#1261'` — baseline-geometry-screened
- Block 40: `'#1321'` — baseline-geometry-screened
- Block 41: `'Selected edge-cases from @hari\'s boolean-test suite'` — baseline-geometry-screened
- Block 42: `'Selected test-cases provided by @iconexperience'` — baseline-geometry-screened
- Block 43: `'Isolated edge-cases from @iconexperience\'s boolean-test suite'` — baseline-geometry-screened
- Block 44: `'#1506'` — baseline-geometry-screened
- Block 45: `'#1513'` — baseline-geometry-screened
- Block 46: `'#1419'` — baseline-geometry-screened
- Block 47: `'#1351'` — baseline-geometry-screened
- Block 48: `'#1647'` — baseline-geometry-screened
- Block 49: `'#1619'` — baseline-geometry-screened
