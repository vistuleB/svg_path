# Core test coverage ledger

All 287 tests passed upstream; a native comparison below covers selected operations, not every assertion.

| Binary / original test | Coverage | Cases | Outcomes |
| --- | --- | ---: | --- |
| `src/core/math/vector2.rs` / `core::math::vector2::tests::ops` | not adapted | 0 |  |
| `src/core/math/base_math.rs` / `core::math::base_math::tests::small_arc_sweep_excludes_opposite_point_at_different_scales` | not adapted | 0 |  |
| `src/core/math/base_math.rs` / `core::math::base_math::tests::arc_sweep_uses_position_tolerance_at_both_boundaries` | not adapted | 0 |  |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::filters_two_polyline_segment_pairs` | selected-operation comparisons | 1 | scope: 1 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::open_polylines_end_touch_start` | selected-operation comparisons | 3 | match: 1, scope: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::open_polylines_end_touch_start_flipped` | selected-operation comparisons | 3 | match: 1, scope: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::open_polylines_start_points_touch` | selected-operation comparisons | 3 | match: 1, scope: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::circles_touching` | selected-operation comparisons | 8 | discrepancy: 2, match: 2, scope: 4 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::circles_overlapping_opposing_direction_flipped` | selected-operation comparisons | 8 | match: 2, contract-difference: 2, scope: 4 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::circles_overlapping_opposing_direction` | selected-operation comparisons | 8 | match: 2, contract-difference: 2, scope: 4 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::circles_overlapping_same_direction` | selected-operation comparisons | 6 | contract-difference: 2, match: 2, scope: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::find_intersects_tests::uses_pos_equal_eps` | selected-operation comparisons | 3 | discrepancy: 1, scope: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::global_self_intersect_tests::circle_no_intersects` | selected-operation comparisons | 28 | scope: 26, match: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::global_self_intersect_tests::filters_global_segment_pairs` | selected-operation comparisons | 4 | scope: 4 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::global_self_intersect_tests::half_circle_overlapping_self` | selected-operation comparisons | 2 | scope: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::global_self_intersect_tests::long_open_polyline_circle` | selected-operation comparisons | 7 | match: 3, scope: 4 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::global_self_intersect_tests::short_open_polyline_circle` | selected-operation comparisons | 29 | match: 3, scope: 26 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::local_self_intersect_tests::circle_no_intersects` | not adapted | 0 |  |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::local_self_intersect_tests::empty_polyline` | not adapted | 0 |  |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::local_self_intersect_tests::filters_local_segment_pairs` | not adapted | 0 |  |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::local_self_intersect_tests::half_circle_overlapping_self` | not adapted | 0 |  |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::local_self_intersect_tests::long_open_polyline_circle` | selected-operation comparisons | 3 | match: 3 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::local_self_intersect_tests::short_open_polyline_circle` | selected-operation comparisons | 1 | match: 1 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::local_self_intersect_tests::single_vertex` | not adapted | 0 |  |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::sort_and_join_overlapping_intersects_tests::overlapping_arcs` | selected-operation comparisons | 22 | match: 6, contract-difference: 5, scope: 11 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::sort_and_join_overlapping_intersects_tests::overlapping_arcs_flipped` | selected-operation comparisons | 23 | match: 7, contract-difference: 5, scope: 11 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::sort_and_join_overlapping_intersects_tests::overlapping_circles_opposing_dir` | selected-operation comparisons | 10 | match: 4, contract-difference: 2, scope: 4 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::sort_and_join_overlapping_intersects_tests::overlapping_circles_perpendicular_vertexes` | selected-operation comparisons | 10 | contract-difference: 4, scope: 4, match: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::sort_and_join_overlapping_intersects_tests::overlapping_circles_same_dir` | selected-operation comparisons | 7 | contract-difference: 2, match: 3, scope: 2 |
| `src/polyline/internal/pline_intersects.rs` / `polyline::internal::pline_intersects::sort_and_join_overlapping_intersects_tests::overlapping_circles_same_dir_flipped_index` | selected-operation comparisons | 7 | contract-difference: 2, match: 3, scope: 2 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::ambiguous_multiway_touch_falls_back_to_preserve_order` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::coincident_coverage_can_span_lines_and_arcs` | selected-operation comparisons | 12 | match: 12 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::discarded_overlap_blocks_preserve_touch_routing_at_shared_boundary` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::dissection_points_sort_into_segment_ranges` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::indexed_node_lookup_handles_unbucketed_coordinates` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::indexed_node_lookup_uses_bucket_probe_order_for_multiple_matches` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::one_occurrence_can_participate_in_several_relations` | selected-operation comparisons | 6 | match: 6 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::one_segment_pair_can_have_two_distinct_contact_nodes` | selected-operation comparisons | 8 | match: 8 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::preserve_collection_records_overlap_boundaries_without_coverage` | selected-operation comparisons | 11 | match: 8, contract-difference: 1, scope: 2 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::preserve_routing_visits_related_slice_before_closing` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::repeated_clip_reports_share_one_occurrence` | selected-operation comparisons | 1 | match: 1 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::repeated_self_contact_reports_share_one_relation` | selected-operation comparisons | 4 | match: 4 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::reversed_relation_reports_merge_and_strengthen_one_pair` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::segment_end_occurrences_are_canonicalized_to_outgoing_segment` | selected-operation comparisons | 4 | match: 4 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::segment_index_compacts_only_for_dense_invalidity` | selected-operation comparisons | 5 | scope: 5 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::self_intersection_collection_records_full_arc_overlap` | selected-operation comparisons | 11 | match: 8, contract-difference: 1, scope: 2 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::separate_behavior_keeps_crossing_closure_order` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::separate_routing_prioritizes_relation_to_initial_occurrence` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::shared_endpoint_reports_use_one_occurrence_in_both_directions` | selected-operation comparisons | 2 | match: 2 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::short_tangent_is_classified_as_crossing` | selected-operation comparisons | 2 | match: 2 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::slices_with_invalid_indexes_are_rejected` | not adapted | 0 |  |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::unrelated_nodes_do_not_connect_by_position` | not adapted | 0 |  |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::closed_raw_offsets_have_segment_aligned_validity` | selected-operation comparisons | 8 | match: 8 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::collapsed_arc_spans_are_invalid` | selected-operation comparisons | 1 | match: 1 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::failed_inner_join_connector_is_recorded_as_invalid` | selected-operation comparisons | 1 | match: 1 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::inner_join_endpoint_tolerance_clamps_the_local_candidate` | selected-operation comparisons | 1 | discrepancy: 1 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::line_line_joins_have_explicit_local_classes` | selected-operation comparisons | 2 | match: 2 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::mixed_and_arc_joins_have_explicit_local_classes` | selected-operation comparisons | 9 | match: 9 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::near_collinear_corner_uses_normalized_angular_tolerance` | not adapted | 0 |  |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::normal_raw_offsets_have_no_invalid_segments` | not adapted | 0 |  |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::raw_arc_span_bulge_uses_cached_sweep_and_trim_parameters` | selected-operation comparisons | 1 | match: 1 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::raw_offset_segments_cache_line_arc_and_collapsed_geometry` | selected-operation comparisons | 1 | match: 1 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::reported_raw_offset_has_an_invalid_source_span` | selected-operation comparisons | 2 | match: 2 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::round_join_bulge_matches_sweep_and_offset_direction` | not adapted | 0 |  |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::unusable_nearest_line_arc_candidate_does_not_select_farther_crossing` | selected-operation comparisons | 2 | match: 2 |
| `src/polyline/internal/raw_pline_offset.rs` / `polyline::internal::raw_pline_offset::tests::zero_raw_offset_is_an_exact_copy` | not adapted | 0 |  |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::dist_from_segment_start_matches_arc_fractions_in_both_directions` | selected-operation comparisons | 30 | match: 30 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::dist_from_segment_start_snaps_near_arc_endpoints` | selected-operation comparisons | 2 | match: 1, discrepancy: 1 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_arc_radius_and_center_returns_expected_geometry` | selected-operation comparisons | 6 | match: 6 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_bounding_box_returns_exact_arc_extents` | selected-operation comparisons | 3 | match: 3 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_closest_point_returns_arc_projection_or_nearest_endpoint` | selected-operation comparisons | 12 | match: 12 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_bounding_box_matches_angle_based_extents` | selected-operation comparisons | 496 | match: 490, discrepancy: 6 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_fast_approx_bounding_box_extends_chord_by_sagitta` | selected-operation comparisons | 4 | scope: 4 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_distance_is_greater_than_matches_closest_point_distance` | selected-operation comparisons | 245 | match: 207, discrepancy: 3, error: 35 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_length_returns_expected_arc_lengths` | selected-operation comparisons | 6 | match: 6 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_midpoint_returns_expected_arc_midpoints` | selected-operation comparisons | 4 | match: 4 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_split_at_point_returns_expected_subarcs` | selected-operation comparisons | 30 | match: 30 |
| `src/polyline/pline_seg.rs` / `polyline::pline_seg::tests::seg_tangent_vector_preserves_arc_radius_magnitude` | selected-operation comparisons | 6 | match: 6 |
| `src/polyline/internal/pline_offset.rs` / `polyline::internal::pline_offset::tests::topology_builder_indexes_large_contact_sets` | not adapted | 0 |  |
| `tests/test_circle_circle_intersect.rs` / `no_intersect_outside` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_circle_circle_intersect.rs` / `overlapping` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_circle_circle_intersect.rs` / `no_intersect_inside` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_circle_circle_intersect.rs` / `tangent_intersect_outside` | selected-operation comparisons | 1 | discrepancy: 1 |
| `tests/test_circle_circle_intersect.rs` / `tangent_intersect_inside` | selected-operation comparisons | 1 | discrepancy: 1 |
| `tests/test_circle_circle_intersect.rs` / `two_intersects` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `near_tangent_intersections_snap_when_positions_are_equal` | selected-operation comparisons | 3 | discrepancy: 3 |
| `tests/test_line_circle_intersect.rs` / `no_intersect` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `near_tangent_intersections_use_position_epsilon_at_different_radii` | selected-operation comparisons | 3 | match: 3 |
| `tests/test_line_circle_intersect.rs` / `tangent_intersect_horizontal` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `tangent_intersect_vertical` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `no_intersect_vertical` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `no_intersect_horizontal` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `point_segment_uses_position_epsilon` | selected-operation comparisons | 1 | error: 1 |
| `tests/test_line_circle_intersect.rs` / `tangent_at_start_point` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `two_intersects_seg_inside_horizontal` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `two_intersects_seg_inside_vertical` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `two_intersects_seg_touching` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_circle_intersect.rs` / `two_intersects_true` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_line_intersect.rs` / `end_point_start_point_touch_same_direction` | selected-operation comparisons | 7 | match: 7 |
| `tests/test_line_line_intersect.rs` / `entirely_overlapping_opposing_direction` | selected-operation comparisons | 7 | contract-difference: 7 |
| `tests/test_line_line_intersect.rs` / `entirely_overlapping_same_direction` | selected-operation comparisons | 6 | contract-difference: 6 |
| `tests/test_line_line_intersect.rs` / `false_intersect` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_line_intersect.rs` / `no_intersect` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_line_intersect.rs` / `no_intersect_vertical` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_line_intersect.rs` / `no_intersect_horizontal` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_line_line_intersect.rs` / `overlapping_intersect` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_line_line_intersect.rs` / `point_intersect` | selected-operation comparisons | 2 | match: 2 |
| `tests/test_line_line_intersect.rs` / `point_intersect_at_end` | selected-operation comparisons | 4 | match: 4 |
| `tests/test_line_line_intersect.rs` / `point_intersect_horizontal` | selected-operation comparisons | 2 | match: 2 |
| `tests/test_line_line_intersect.rs` / `point_intersect_vertical` | selected-operation comparisons | 2 | match: 2 |
| `tests/test_line_line_intersect.rs` / `start_points_touch_opposing_direction` | selected-operation comparisons | 7 | match: 7 |
| `tests/test_line_line_intersect.rs` / `true_intersect` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_basics.rs` / `area` | selected-operation comparisons | 12 | match: 7, scope: 5 |
| `tests/test_pline_basics.rs` / `iter_segments` | not adapted | 0 |  |
| `tests/test_pline_basics.rs` / `find_point_at_path_length` | selected-operation comparisons | 15 | match: 13, error: 1, scope: 1 |
| `tests/test_pline_basics.rs` / `create_from_remove_repeat` | not adapted | 0 |  |
| `tests/test_pline_basics.rs` / `invert_direction_mut` | not adapted | 0 |  |
| `tests/test_pline_basics.rs` / `extents` | selected-operation comparisons | 9 | scope: 3, match: 6 |
| `tests/test_pline_basics.rs` / `iter_segment_indexes` | not adapted | 0 |  |
| `tests/test_pline_basics.rs` / `path_length` | selected-operation comparisons | 11 | scope: 1, match: 10 |
| `tests/test_pline_basics.rs` / `iter_vertexes` | not adapted | 0 |  |
| `tests/test_pline_basics.rs` / `remove_redundant` | selected-operation comparisons | 32 | match: 32 |
| `tests/test_pline_basics.rs` / `remove_redundant_removes_repeat_pos` | selected-operation comparisons | 3 | match: 3 |
| `tests/test_pline_basics.rs` / `remove_repeat` | not adapted | 0 |  |
| `tests/test_pline_basics.rs` / `rotate_start` | selected-operation comparisons | 2 | match: 2 |
| `tests/test_pline_boolean.rs` / `test_same::origin_circle` | selected-operation comparisons | 57 | helper-only: 3, match: 54 |
| `tests/test_pline_boolean.rs` / `test_same::origin_circle2` | selected-operation comparisons | 57 | helper-only: 3, match: 54 |
| `tests/test_pline_boolean.rs` / `test_same::rectangle` | selected-operation comparisons | 57 | helper-only: 3, match: 54 |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_in_rectangle_two_edge_overlap` | selected-operation comparisons | 19 | match: 16, helper-only: 3 |
| `tests/test_pline_boolean.rs` / `test_same::diamond` | selected-operation comparisons | 57 | helper-only: 3, match: 54 |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_in_rectangle_one_edge_overlap_flipped_order` | selected-operation comparisons | 19 | match: 16, helper-only: 3 |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_in_rectangle_one_edge_overlap` | selected-operation comparisons | 19 | match: 16, helper-only: 3 |
| `tests/test_pline_boolean.rs` / `test_same::case3` | selected-operation comparisons | 57 | helper-only: 3, match: 54 |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_over_half_of_circle` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_slicing_circle` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_simple::rectangle_in_rectangle_two_edge_overlap_flipped_order` | selected-operation comparisons | 19 | match: 16, helper-only: 3 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported11` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported10` | selected-operation comparisons | 19 | match: 3, helper-only: 3, discrepancy: 9, error: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::debug_assert_stitching_slices_reported` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported12` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported13` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported2` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported3` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported4` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported5_modified` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported5` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported6` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported7` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::parametric_from_point_debug_assert_reported1` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported8` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::overlapping_pill_shaped_ends_reported9` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_boolean.rs` / `test_specific::parametric_from_point_debug_assert_reported2` | selected-operation comparisons | 19 | error: 16, helper-only: 3 |
| `tests/test_pline_boolean.rs` / `test_same::case2` | selected-operation comparisons | 57 | helper-only: 3, match: 54 |
| `tests/test_pline_boolean.rs` / `test_specific::pill_shapes_overlapping_at_ends_at_acute_angle` | selected-operation comparisons | 19 | match: 8, helper-only: 3, discrepancy: 8 |
| `tests/test_pline_boolean.rs` / `test_specific::pill_shapes_overlapping_at_ends_90_deg` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::mostly_overlapping_case1` | selected-operation comparisons | 19 | match: 16, helper-only: 3 |
| `tests/test_pline_boolean.rs` / `test_same::case1` | selected-operation comparisons | 77 | helper-only: 3, match: 74 |
| `tests/test_pline_boolean.rs` / `test_specific::mostly_overlapping_case2` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_boolean.rs` / `test_specific::opposite_direction_arc_arc_endpoints_intersect_bug_reported` | selected-operation comparisons | 19 | match: 12, helper-only: 3, discrepancy: 4 |
| `tests/test_pline_contains.rs` / `test_pline_contains::test_copy` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_contains.rs` / `test_pline_contains::test_invalid` | selected-operation comparisons | 2 | scope: 2 |
| `tests/test_pline_contains.rs` / `test_pline_contains::test_self_intersect_scan` | selected-operation comparisons | 5 | match: 5 |
| `tests/test_pline_contains.rs` / `test_pline_contains::test_rectangle_contains_circle` | selected-operation comparisons | 2 | match: 2 |
| `tests/test_pline_contains.rs` / `test_pline_contains::test_rectangle_intersects_circle` | selected-operation comparisons | 2 | match: 2 |
| `tests/test_pline_contains.rs` / `test_pline_contains::test_disjoint` | selected-operation comparisons | 2 | match: 2 |
| `tests/test_pline_parallel_offset.rs` / `exact_zero_offset_returns_an_unchanged_copy` | selected-operation comparisons | 8 | scope: 4, match: 4 |
| `tests/test_pline_parallel_offset.rs` / `closed_inward_offset_collapsed_returns_no_result` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_parallel_offset.rs` / `repeat_position_input_ignores_external_aabb_after_sanitize` | selected-operation comparisons | 4 | match: 1, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `default_behavior_preserves_tangent_touching_small_loop` | selected-operation comparisons | 11 | match: 10, discrepancy: 1 |
| `tests/test_pline_parallel_offset.rs` / `repeat_position_input_is_sanitized_before_offset` | selected-operation comparisons | 4 | match: 1, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `coincident_discard_does_not_remove_a_point_only_tangent` | selected-operation comparisons | 11 | discrepancy: 1, match: 10 |
| `tests/test_pline_parallel_offset.rs` / `offset_does_not_self_intersect` | selected-operation comparisons | 4 | discrepancy: 1, match: 3 |
| `tests/test_pline_parallel_offset.rs` / `collapsed_rectangle_preserves_or_discards_coincident_centerline` | selected-operation comparisons | 4 | match: 1, helper-only: 2, discrepancy: 1 |
| `tests/test_pline_parallel_offset.rs` / `next_offset_removes_collapsed_small_loop` | selected-operation comparisons | 8 | discrepancy: 1, error: 1, match: 6 |
| `tests/test_pline_parallel_offset.rs` / `repeat_position_real_world_input_is_sanitized_before_offset` | selected-operation comparisons | 4 | discrepancy: 1, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `coincident_discard_removes_same_direction_and_opposing_partial_spans` | selected-operation comparisons | 5 | discrepancy: 3, helper-only: 1, match: 1 |
| `tests/test_pline_parallel_offset.rs` / `separate_behavior_splits_tangent_touching_small_loop` | selected-operation comparisons | 14 | match: 8, discrepancy: 2, helper-only: 3, error: 1 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline8` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline1` | selected-operation comparisons | 7 | discrepancy: 2, helper-only: 3, match: 2 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline2` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::issue82_small_joining_arc` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline3` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::near_tangent_line_arc_joins` | selected-operation comparisons | 5 | error: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::open_pline1` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline7` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::open_pline2` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::open_pline3` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::issue77_repeated_offset` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::open_pline5` | selected-operation comparisons | 5 | error: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::small_bulge_arc_line_transition` | selected-operation comparisons | 4 | discrepancy: 1, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::sub_tolerance_raw_offset_arc_does_not_panic` | selected-operation comparisons | 4 | discrepancy: 1, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::open_pline4` | selected-operation comparisons | 5 | discrepancy: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::circle_collapsed` | selected-operation comparisons | 4 | discrepancy: 4 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline6` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::circle_collapsed_into_point` | selected-operation comparisons | 4 | error: 4 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline4` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::closed_circle_offset_inward` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::closed_circle_offset_outward` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::empty_returns_empty` | selected-operation comparisons | 2 | scope: 2 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::closed_diamond_offset_inward` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::open_diamond_offset_outward` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::closed_rectangle_into_overlapping_line` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::open_rectangle_inward` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::closed_rectangle_inward` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::open_diamond_offset_inward` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::closed_diamond_offset_outward` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::open_rectangle_outward` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::closed_rectangle_outward` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::square_collapsed` | selected-operation comparisons | 4 | discrepancy: 4 |
| `tests/test_pline_parallel_offset.rs` / `test_simple::square_collapsed_into_point` | selected-operation comparisons | 4 | match: 4 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case15` | selected-operation comparisons | 7 | match: 2, helper-only: 3, discrepancy: 2 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case14` | selected-operation comparisons | 7 | discrepancy: 2, helper-only: 3, match: 2 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case10` | selected-operation comparisons | 7 | discrepancy: 2, helper-only: 3, match: 2 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline9` | selected-operation comparisons | 7 | discrepancy: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case1` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case3` | selected-operation comparisons | 4 | match: 4 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case13` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case4` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case5` | selected-operation comparisons | 5 | discrepancy: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case6` | selected-operation comparisons | 5 | error: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case7` | selected-operation comparisons | 5 | match: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case2` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::self_intersecting_case1` | selected-operation comparisons | 5 | discrepancy: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case9` | selected-operation comparisons | 7 | discrepancy: 2, helper-only: 3, match: 2 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::self_intersecting_case2` | selected-operation comparisons | 5 | discrepancy: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case16` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case8` | selected-operation comparisons | 7 | discrepancy: 2, helper-only: 3, match: 2 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case17` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::non_tangent_open_endpoint_clip` | selected-operation comparisons | 11 | error: 8, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::disjoint_same_direction_coincident_spans` | selected-operation comparisons | 11 | discrepancy: 8, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::opposing_coincident_arcs_vertex_boundaries` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::same_direction_coincident_open_arcs` | selected-operation comparisons | 11 | discrepancy: 8, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::same_direction_coincident_open_lines` | selected-operation comparisons | 11 | discrepancy: 8, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::same_direction_coincident_open_line_arc` | selected-operation comparisons | 11 | discrepancy: 8, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::opposing_coincident_arcs_segment_interior_boundaries` | selected-operation comparisons | 19 | match: 4, helper-only: 3, discrepancy: 12 |
| `tests/test_pline_parallel_offset.rs` / `test_past_failures::closed_pline5` | selected-operation comparisons | 7 | match: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::three_way_coincident_lines` | selected-operation comparisons | 11 | discrepancy: 8, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::touch_at_coincident_overlap_boundary` | selected-operation comparisons | 11 | discrepancy: 8, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `touching_loop_behavior_does_not_change_crossing_routing` | selected-operation comparisons | 5 | discrepancy: 2, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::tangent_arc_arc_segment_interiors` | selected-operation comparisons | 19 | error: 16, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::tangent_line_arc_segment_interiors` | selected-operation comparisons | 19 | match: 8, helper-only: 3, discrepancy: 8 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::coincident_line_dumbbell_vertex_boundaries` | selected-operation comparisons | 19 | match: 8, helper-only: 3, discrepancy: 8 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::coincident_line_dumbbell_segment_interior_boundaries` | selected-operation comparisons | 19 | match: 8, helper-only: 3, discrepancy: 8 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::tangent_line_endpoints` | selected-operation comparisons | 19 | match: 8, helper-only: 3, discrepancy: 8 |
| `tests/test_pline_parallel_offset.rs` / `test_topology_stitching::three_way_point_contact_keeps_paths_separate` | selected-operation comparisons | 19 | match: 16, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case11` | selected-operation comparisons | 7 | discrepancy: 4, helper-only: 3 |
| `tests/test_pline_parallel_offset.rs` / `test_specific::case12` | selected-operation comparisons | 7 | discrepancy: 2, helper-only: 3, match: 2 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_end_points_touch` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc1_within_arc2_overlapping` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc2_within_arc1_overlapping_reverse_dir` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc2_within_arc1_overlapping` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_end_points_touch_reverse_dir` | selected-operation comparisons | 3 | match: 3 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_opposite_direction_touch_at_ends_bug` | selected-operation comparisons | 3 | discrepancy: 3 |
| `tests/test_pline_seg_intersect.rs` / `arc1_within_arc2_overlapping_reverse_dir` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_partial_overlap` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_partial_overlap_arc1_reverse_dir` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_partial_overlap_arc1_reverse_dir_flipped` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_partial_overlap_arc2_reverse_dir` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_partial_overlap_arc2_reverse_dir_flipped` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_arc_partial_overlap_flipped` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `arc_line_no_intersect` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_seg_intersect.rs` / `line_arc_intersect_sticks_to_fuzzy_circle_endpoint` | selected-operation comparisons | 1 | discrepancy: 1 |
| `tests/test_pline_seg_intersect.rs` / `line_arc_no_intersect` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_seg_intersect.rs` / `overlapping_arc_endpoint_touch_uses_position_tolerance` | selected-operation comparisons | 6 | discrepancy: 3, match: 3 |
| `tests/test_pline_seg_intersect.rs` / `overlapping_arcs_handle_angle_wrap_at_different_scales` | selected-operation comparisons | 3 | contract-difference: 3 |
| `tests/test_pline_seg_intersect.rs` / `overlapping_lines` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `overlapping_lines_reverse_dir` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `overlapping_same_arcs` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_seg_intersect.rs` / `overlapping_same_arcs_reverse_dir` | selected-operation comparisons | 1 | contract-difference: 1 |
| `tests/test_pline_view.rs` / `from_new_start` | selected-operation comparisons | 10 | match: 10 |
| `tests/test_pline_view.rs` / `from_slice_points_single_seg` | selected-operation comparisons | 12 | match: 12 |
| `tests/test_pline_view.rs` / `from_slice_points_collapsed_across_near_vertex` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_view.rs` / `from_slice_points_multi_seg` | selected-operation comparisons | 10 | match: 10 |
| `tests/test_pline_view.rs` / `attempting_to_wrap_slice_on_open_pline - should panic` | not adapted | 0 |  |
| `tests/test_pline_winding_number.rs` / `point_and_circle` | selected-operation comparisons | 4 | match: 4 |
| `tests/test_pline_winding_number.rs` / `point_and_circle_with_quarter_arcs` | selected-operation comparisons | 3 | match: 3 |
| `tests/test_pline_winding_number.rs` / `multiple_windings` | selected-operation comparisons | 4 | match: 2, contract-difference: 2 |
| `tests/test_pline_winding_number.rs` / `point_outside_aligned_with_direction_vectors2` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_winding_number.rs` / `point_outside_aligned_with_direction_vectors1` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_pline_winding_number.rs` / `point_and_rectangle` | selected-operation comparisons | 4 | match: 4 |
| `tests/test_shape_parallel_offset.rs` / `test_simple::set_of_empty_returns_empty` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_shape_parallel_offset.rs` / `test_simple::empty_returns_empty` | selected-operation comparisons | 1 | match: 1 |
| `tests/test_shape_parallel_offset.rs` / `test_specific::case1` | selected-operation comparisons | 4 | helper-only: 3, match: 1 |
| `tests/test_shape_parallel_offset.rs` / `test_simple::rectangle_inside_shape` | selected-operation comparisons | 4 | helper-only: 3, match: 1 |
| `tests/test_shape_parallel_offset.rs` / `test_specific::case2` | selected-operation comparisons | 4 | helper-only: 3, match: 1 |
| `tests/test_shape_parallel_offset.rs` / `test_specific::case3` | selected-operation comparisons | 4 | helper-only: 3, error: 1 |
