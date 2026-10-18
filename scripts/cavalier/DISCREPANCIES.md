# Comparative discrepancy inventory

Raw flags only: not a confirmed-bug count. Comparison and adapter limits are in `REVIEW.md`.

| Original file / test | Operation | Flags | Outcomes | Representative case |
| --- | --- | ---: | --- | --- |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::circles_touching` | `pline_seg_intr` | 2 | discrepancy: 2 | `CC00013` |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::uses_pos_equal_eps` | `pline_seg_intr` | 1 | discrepancy: 1 | `CC00020` |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::inner_join_endpoint_tolerance_clamps_the_local_candidate` | `line_line_intr` | 1 | discrepancy: 1 | `CC00057` |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::dist_from_segment_start_snaps_near_arc_endpoints` | `dist_from_segment_start` | 1 | discrepancy: 1 | `CX00167` |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_bounding_box_matches_angle_based_extents` | `seg_arc_radius_and_center` | 3 | discrepancy: 3 | `CX00420` |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_bounding_box_matches_angle_based_extents` | `seg_bounding_box` | 3 | discrepancy: 3 | `CX00421` |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_distance_is_greater_than_matches_closest_point_distance` | `seg_closest_point` | 8 | discrepancy: 3, DistanceMaxIterationsReached: 5 | `CX00755` |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_distance_is_greater_than_matches_closest_point_distance` | `seg_distance_is_greater_than` | 30 | DistanceMaxIterationsReached: 30 | `CX00882` |
| `tests/test_circle_circle_intersect.rs` / `tangent_intersect_inside` | `circle_circle_intr` | 1 | discrepancy: 1 | `CC00070` |
| `tests/test_circle_circle_intersect.rs` / `tangent_intersect_outside` | `circle_circle_intr` | 1 | discrepancy: 1 | `CC00071` |
| `tests/test_line_circle_intersect.rs` / `near_tangent_intersections_snap_when_positions_are_equal` | `line_circle_intr` | 3 | discrepancy: 3 | `CC00073` |
| `tests/test_line_circle_intersect.rs` / `point_segment_uses_position_epsilon` | `line_circle_intr` | 1 | IndeterminateDirection: 1 | `CC00082` |
| `tests/test_pline_basics.rs` / `find_point_at_path_length` | `find_point_at_path_length` | 1 | InvalidLengthDistance: 1 | `CX00982` |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_over_half_of_circle` | `boolean` | 4 | discrepancy: 4 | `CC00666` |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_slicing_circle` | `boolean` | 4 | discrepancy: 4 | `CC00685` |
| `tests/test_pline_boolean.rs` / `test_specific::debug_assert_stitching_slices_reported` | `boolean` | 4 | discrepancy: 4 | `CC00704` |
| `tests/test_pline_boolean.rs` / `test_specific::mostly_overlapping_case2` | `boolean` | 4 | discrepancy: 4 | `CC00742` |
| `tests/test_pline_boolean.rs` / `test_specific::opposite_direction_arc_arc_endpoints_intersect_bug_reported` | `boolean` | 4 | discrepancy: 4 | `CC00761` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported` | `boolean` | 4 | discrepancy: 4 | `CC00780` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported10` | `boolean` | 13 | discrepancy: 9, ArrangementGraphError: 4 | `CC00797` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported11` | `boolean` | 12 | discrepancy: 12 | `CC00816` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported12` | `boolean` | 12 | discrepancy: 12 | `CC00835` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported13` | `boolean` | 12 | discrepancy: 12 | `CC00854` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported2` | `boolean` | 4 | discrepancy: 4 | `CC00875` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported3` | `boolean` | 4 | discrepancy: 4 | `CC00894` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported4` | `boolean` | 4 | discrepancy: 4 | `CC00913` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported5` | `boolean` | 12 | discrepancy: 12 | `CC00930` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported5_modified` | `boolean` | 12 | discrepancy: 12 | `CC00949` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported6` | `boolean` | 12 | discrepancy: 12 | `CC00968` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported7` | `boolean` | 4 | discrepancy: 4 | `CC00989` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported8` | `boolean` | 12 | discrepancy: 12 | `CC01006` |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported9` | `boolean` | 12 | discrepancy: 12 | `CC01025` |
| `tests/test_pline_boolean.rs` / `test_specific::parametric_from_point_debug_assert_reported1` | `boolean` | 4 | discrepancy: 4 | `CC01046` |
| `tests/test_pline_boolean.rs` / `test_specific::parametric_from_point_debug_assert_reported2` | `boolean` | 16 | ArrangementGraphError: 16 | `CC01059` |
| `tests/test_pline_boolean.rs` / `test_specific::pill_shapes_overlapping_at_ends_90_deg` | `boolean` | 4 | discrepancy: 4 | `CC01084` |
| `tests/test_pline_boolean.rs` / `test_specific::pill_shapes_overlapping_at_ends_at_acute_angle` | `boolean` | 8 | discrepancy: 8 | `CC01102` |
| `tests/test_pline_parallel_offset.rs` / `coincident_discard_does_not_remove_a_point_only_tangent` | `offset` | 1 | discrepancy: 1 | `CC01131` |
| `tests/test_pline_parallel_offset.rs` / `coincident_discard_removes_same_direction_and_opposing_partial_spans` | `offset` | 3 | discrepancy: 3 | `CC01142` |
| `tests/test_pline_parallel_offset.rs` / `collapsed_rectangle_preserves_or_discards_coincident_centerline` | `offset` | 1 | discrepancy: 1 | `CC01150` |
| `tests/test_pline_parallel_offset.rs` / `default_behavior_preserves_tangent_touching_small_loop` | `offset` | 1 | discrepancy: 1 | `CC01151` |
| `tests/test_pline_parallel_offset.rs` / `next_offset_removes_collapsed_small_loop` | `offset` | 2 | discrepancy: 1, PathError: 1 | `CC01151` |
| `tests/test_pline_parallel_offset.rs` / `offset_does_not_self_intersect` | `offset` | 1 | discrepancy: 1 | `CC01167` |
| `tests/test_pline_parallel_offset.rs` / `repeat_position_real_world_input_is_sanitized_before_offset` | `offset` | 1 | discrepancy: 1 | `CC01179` |
| `tests/test_pline_parallel_offset.rs` / `separate_behavior_splits_tangent_touching_small_loop` | `offset` | 2 | discrepancy: 1, PathError: 1 | `CC01183` |
| `tests/test_pline_parallel_offset.rs` / `separate_behavior_splits_tangent_touching_small_loop` | `pline_seg_intr` | 1 | discrepancy: 1 | `CC01188` |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline1` | `offset` | 2 | discrepancy: 2 | `CC01192` |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline9` | `offset` | 4 | discrepancy: 4 | `CC01248` |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::near_tangent_line_arc_joins` | `offset` | 2 | ConstructionFailed: 2 | `CC01267` |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::open_pline4` | `offset` | 2 | discrepancy: 2 | `CC01287` |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::open_pline5` | `offset` | 2 | PathError: 2 | `CC01292` |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::small_bulge_arc_line_transition` | `offset` | 1 | discrepancy: 1 | `CC01297` |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::sub_tolerance_raw_offset_arc_does_not_panic` | `offset` | 1 | discrepancy: 1 | `CC01301` |
| `tests/test_pline_parallel_offset.rs` / `test_simple::circle_collapsed` | `offset` | 4 | discrepancy: 4 | `CC01305` |
| `tests/test_pline_parallel_offset.rs` / `test_simple::circle_collapsed_into_point` | `offset` | 4 | DegenerateTangent: 4 | `CC01309` |
| `tests/test_pline_parallel_offset.rs` / `test_simple::square_collapsed` | `offset` | 4 | discrepancy: 4 | `CC01383` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case10` | `offset` | 2 | discrepancy: 2 | `CC01398` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case11` | `offset` | 4 | discrepancy: 4 | `CC01405` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case12` | `offset` | 2 | discrepancy: 2 | `CC01412` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case14` | `offset` | 2 | discrepancy: 2 | `CC01426` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case15` | `offset` | 2 | discrepancy: 2 | `CC01438` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case5` | `offset` | 2 | discrepancy: 2 | `CC01470` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case6` | `offset` | 2 | DegenerateTangent: 2 | `CC01475` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case8` | `offset` | 2 | discrepancy: 2 | `CC01485` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case9` | `offset` | 2 | discrepancy: 2 | `CC01492` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::self_intersecting_case1` | `offset` | 2 | discrepancy: 2 | `CC01499` |
| `tests/test_pline_parallel_offset.rs` / `test_specific::self_intersecting_case2` | `offset` | 2 | discrepancy: 2 | `CC01504` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::coincident_line_dumbbell_segment_interior_boundaries` | `offset` | 8 | discrepancy: 8 | `CC01520` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::coincident_line_dumbbell_vertex_boundaries` | `offset` | 8 | discrepancy: 8 | `CC01539` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::disjoint_same_direction_coincident_spans` | `offset` | 8 | discrepancy: 8 | `CC01547` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::non_tangent_open_endpoint_clip` | `offset` | 8 | ConstructionFailed: 8 | `CC01558` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::opposing_coincident_arcs_segment_interior_boundaries` | `offset` | 12 | discrepancy: 12 | `CC01574` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::opposing_coincident_arcs_vertex_boundaries` | `offset` | 12 | discrepancy: 12 | `CC01593` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::same_direction_coincident_open_arcs` | `offset` | 8 | discrepancy: 8 | `CC01607` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::same_direction_coincident_open_line_arc` | `offset` | 8 | discrepancy: 8 | `CC01618` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::same_direction_coincident_open_lines` | `offset` | 8 | discrepancy: 8 | `CC01629` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::tangent_arc_arc_segment_interiors` | `offset` | 16 | ConstructionFailed: 16 | `CC01640` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::tangent_line_arc_segment_interiors` | `offset` | 8 | discrepancy: 8 | `CC01670` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::tangent_line_endpoints` | `offset` | 8 | discrepancy: 8 | `CC01689` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::three_way_coincident_lines` | `offset` | 8 | discrepancy: 8 | `CC01697` |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::touch_at_coincident_overlap_boundary` | `offset` | 8 | discrepancy: 8 | `CC01727` |
| `tests/test_pline_parallel_offset.rs` / `touching_loop_behavior_does_not_change_crossing_routing` | `offset` | 2 | discrepancy: 2 | `CC01738` |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_opposite_direction_touch_at_ends_bug` | `pline_seg_intr` | 3 | discrepancy: 3 | `CC01751` |
| `tests/test_pline_seg_intersect.rs` / `line_arc_intersect_sticks_to_fuzzy_circle_endpoint` | `pline_seg_intr` | 1 | discrepancy: 1 | `CC01761` |
| `tests/test_pline_seg_intersect.rs` / `overlapping_arc_endpoint_touch_uses_position_tolerance` | `pline_seg_intr` | 3 | discrepancy: 3 | `CC01763` |
| `tests/test_shape_parallel_offset.rs` / `test_specific::case3` | `shape_offset` | 1 | ConstructionFailed: 1 | `CC01807` |

Full inputs are in `captured-cases.json` and `extra-cases.json`; native outcomes are in the matching results JSONL files. `discrepancy-queue.json` contains every raw flag. The same case may occur in multiple tests; rows do not count independent bugs.
