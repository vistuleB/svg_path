# Path.js

[Audit index](../INDEX.md) · [Archive](../upstream/Path.js)

Original path: `test/tests/Path.js`.
Pinned revision: `92775f5279c05fb7f0a743e9e7fa02cd40ec1e70`; extraction runtime: `paper@0.12.18`.
SHA-256: `1bf6d952d9bf4ca619bc04018b69367a2985e97cd5607fb9575e677e6705a4f6`.
Download date: not recorded. Archive consolidated: 2026-10-14.

## Scope

Detailed core inventory; see inventory.json and linked reports.

prior detailed audit plus final dispositions.

This file-level disposition is not a claim that every assertion was executed or passed.

## Fast release adaptations

[svg_path_paper_paths_test.gleam](../../../test/svg_path_paper_paths_test.gleam)

- `paper_path_length_test`
- `paper_path_quarter_length_test`
- `paper_path_area_0_test`
- `paper_path_area_1_test`
- `paper_path_join_0_test`
- `paper_path_join_1_test`
- `paper_path_join_2_test`
- `paper_path_join_3_test`
- `paper_path_join_tolerance_0_test`
- `paper_path_join_tolerance_1_test`
- `paper_path_reverse_test`
- `paper_path_flatten_24_test`
- `paper_path_flatten_25_test`
- `paper_path_split_28_test`
- `paper_path_split_29_test`
- `paper_path_line_to_test`

[svg_path_paper_path_arcs_test.gleam](../../../test/svg_path_paper_path_arcs_test.gleam)

- `paper_1613_coincident_endpoint_arc_normalizes_to_move_test`

[svg_path_paper_path_tangents_test.gleam](../../../test/svg_path_paper_path_tangents_test.gleam)

- `paper_horizontal_tangent_offsets_at_joins_test`
- `paper_diagonal_tangent_offsets_inside_curves_test`

[svg_path_paper_path_coincident_test.gleam](../../../test/svg_path_paper_path_coincident_test.gleam)

- `paper_three_coincident_nodes_normalize_to_move_test`

## Slow release adaptations

None.

## Shared adaptation helpers

None.

## Native regressions with related provenance

- [svg_path_large_construction_test.gleam](../../../test/svg_path_large_construction_test.gleam)
- [svg_path_parse_tokenizer_stack_test.gleam](../../../test/svg_path_parse_tokenizer_stack_test.gleam)
- [svg_path_parse_dispatch_stack_test.gleam](../../../test/svg_path_parse_dispatch_stack_test.gleam)

## Diagnostic probes (not release tests)

- [paper_bulk_checks.gleam](../../../test_paperjs/src/paper_bulk_checks.gleam)

## Raw comparison drivers (not release tests)

None.

## Evidence and extracted fixtures

- [path-status.json](../path-status.json)
- [PATH_ARCS.md](../PATH_ARCS.md)
- [PATH_TANGENTS.md](../PATH_TANGENTS.md)
- [PATH_COINCIDENT.md](../PATH_COINCIDENT.md)
- [LARGE_CONSTRUCTION_FIX.md](../LARGE_CONSTRUCTION_FIX.md)
- [STACK_OVERFLOW_INVESTIGATION.md](../STACK_OVERFLOW_INVESTIGATION.md)
- [paths.json](../paths.json)
- [path-arcs.json](../path-arcs.json)
- [path-tangents.json](../path-tangents.json)
- [path-coincident.json](../path-coincident.json)

## Original test blocks

Original titles and historical block dispositions from `inventory.json`.
Consult the evidence above and the current README for subsequent fixes; these are not live pass/fail results.

- Block 0: `'Path#length'` — adapted-geometry-checks
- Block 1: `'Path#area'` — adapted-geometry-checks
- Block 2: `'Path#equals(path)'` — object-api-out-of-scope
- Block 3: `'Path#join(path)'` — adapted-geometry-checks
- Block 4: `'Path#join(path, tolerance)'` — adapted-geometry-checks
- Block 5: `'Path#remove()'` — object-api-out-of-scope
- Block 6: `'Path#removeSegments()'` — object-api-out-of-scope
- Block 7: `'Is the path deselected after setting a new list of segments?'` — object-api-out-of-scope
- Block 8: `'Setting Path#fullySelected=true on an empty path should only set path#selected=true'` — object-api-out-of-scope
- Block 9: `'After removing all segments of a fully selected path, it should still be selected.'` — object-api-out-of-scope
- Block 10: `'After removing all segments of a selected path, it should still be selected.'` — object-api-out-of-scope
- Block 11: `'After simplifying a path using #simplify(), the path should stay fullySelected'` — object-api-out-of-scope
- Block 12: `'After cloning a selected item, it should be added to the Project#selectedItems array'` — object-api-out-of-scope
- Block 13: `'After simplifying a path using #simplify(), the path should stay selected'` — object-api-out-of-scope
- Block 14: `'After smoothing a path using #smooth(), the path should stay fullySelected'` — object-api-out-of-scope
- Block 15: `'After smoothing a path using #smooth(), the path should stay selected'` — object-api-out-of-scope
- Block 16: `'After selecting a segment, Path#selected should return true'` — object-api-out-of-scope
- Block 17: `'Path#reverse()'` — adapted-geometry-checks
- Block 18: `'Path#reverse() should adjust segment indices'` — object-api-out-of-scope
- Block 19: `'Path#fullySelected'` — object-api-out-of-scope
- Block 20: `'Simplifying a path with three segments of the same position should not throw an error'` — adapted-geometry-checks
- Block 21: `'Path#interpolate(from, to, factor)'` — no-direct-public-counterpart
- Block 22: `'Path#curves synchronisation'` — object-api-out-of-scope
- Block 23: `'Path#curves on closed paths'` — object-api-out-of-scope
- Block 24: `'Path#flatten(maxDistance)'` — adapted-geometry-checks
- Block 25: `'Path#single segment closed path flatten (#1338)'` — adapted-geometry-checks
- Block 26: `'Path#curves after removing a segment - 1'` — object-api-out-of-scope
- Block 27: `'Path#curves after removing a segment - 2'` — object-api-out-of-scope
- Block 28: `'Splitting a straight path should produce segments without handles'` — adapted-geometry-checks
- Block 29: `'Splitting a path with one curve in the middle result in two paths of the same length with one curve each'` — adapted-geometry-checks
- Block 30: `'Path#lineTo(point);'` — adapted-geometry-checks
- Block 31: `'Path#arcTo(from, through, to);'` — no-direct-public-counterpart
- Block 32: `'Path#arcTo(from, through, to); where from, through and to all share the same y position and through lies in between from and to'` — no-direct-public-counterpart
- Block 33: `'Path#arcTo(from, through, to); where from, through and to all share the same y position and through lies to the right of to'` — no-direct-public-counterpart
- Block 34: `'Path#arcTo(from, through, to); where from, through and to all share the same y position and through lies to the left of to'` — no-direct-public-counterpart
- Block 35: `'Path#getOffsetsWithTangent()'` — adapted-geometry-checks
- Block 36: `'Path#add() with a lot of segments (#1493)'` — confirmed-javascript-stack-overflow
- Block 37: `'Path#arcTo(through, to) is on through point side (#1477)'` — no-direct-public-counterpart
- Block 38: `'Path#arcTo(to, radius, rotation, clockwise, large) when from and to are equal (#1613)'` — adapted-svg-normalization-match
- Block 39: `'Path#closed with blend mode'` — object-api-out-of-scope
